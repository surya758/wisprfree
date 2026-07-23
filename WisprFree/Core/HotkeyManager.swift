import AppKit
import ApplicationServices

/// Global dictation hotkeys via a CGEvent tap (needs Accessibility).
/// Three user-recorded bindings (Settings → Hotkeys, applied per-event so
/// changes take effect immediately):
/// - Push-to-talk: hold, speak, release to insert. Tapping it also stops a
///   hands-free recording.
/// - Hands-free toggle: press to start, press again to stop and insert.
/// - Cancel: discard the current recording.
@MainActor
final class HotkeyManager {
    enum Style { case none, holdToTalk, handsFree }

    private let pipeline: DictationPipeline
    private var tap: CFMachPort?
    private var style: Style = .none
    private var holdKeyIsDown = false
    /// Bare-modifier keys currently pressed (for edge detection).
    private var modifiersDown: Set<Int> = []
    /// Set when a press was consumed as "stop"; its release must do nothing.
    private var ignoreCurrentPress = false
    private var retryTimer: Timer?

    init(pipeline: DictationPipeline) {
        self.pipeline = pipeline
        if !installTap() {
            // Accessibility not granted yet — keep retrying until it is.
            retryTimer = Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { [weak self] _ in
                Task { @MainActor in
                    guard let self, self.tap == nil else {
                        self?.retryTimer?.invalidate()
                        return
                    }
                    if self.installTap() { self.retryTimer?.invalidate() }
                }
            }
        }
    }

    /// Called when a recording is stopped from outside the key flow
    /// (e.g. the overlay's ✕ button), so key state stays consistent.
    func resetStyle() {
        style = .none
        ignoreCurrentPress = holdKeyIsDown
    }

    private func installTap() -> Bool {
        guard AXIsProcessTrusted() else { return false }
        let mask = (1 << CGEventType.flagsChanged.rawValue)
            | (1 << CGEventType.keyDown.rawValue)
            | (1 << CGEventType.keyUp.rawValue)
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(mask),
            callback: { _, type, event, userInfo in
                let manager = Unmanaged<HotkeyManager>.fromOpaque(userInfo!).takeUnretainedValue()
                return manager.handle(type: type, event: event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else { return false }

        self.tap = tap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        return true
    }

    /// Runs on the main run loop (tap source is scheduled there).
    private nonisolated func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        // The system disables taps that are slow to respond; re-enable.
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            MainActor.assumeIsolated {
                if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            }
            return Unmanaged.passUnretained(event)
        }

        return MainActor.assumeIsolated {
            let settings = AppSettings.current
            let hold = settings.holdBinding
            let toggle = settings.toggleBinding
            let cancel = settings.cancelBinding
            let keyCode = Int(event.getIntegerValueField(.keyboardEventKeycode))
            let flags = event.flags.rawValue

            switch type {
            case .flagsChanged:
                guard let mask = HotkeyBinding.modifierMasks[keyCode] else { break }
                let down = flags & mask != 0
                let wasDown = modifiersDown.contains(keyCode)
                guard down != wasDown else { break }
                if down { modifiersDown.insert(keyCode) } else { modifiersDown.remove(keyCode) }

                if hold.isModifierAlone, keyCode == hold.keyCode {
                    holdKeyIsDown = down
                    down ? holdKeyPressed() : holdKeyReleased()
                } else if down, toggle.isModifierAlone, keyCode == toggle.keyCode {
                    toggleAction()
                } else if down, cancel.isModifierAlone, keyCode == cancel.keyCode, style != .none {
                    cancelAction()
                }

            case .keyDown:
                guard event.getIntegerValueField(.keyboardEventAutorepeat) == 0 else {
                    // Swallow autorepeat of a held non-modifier dictation key.
                    if !hold.isModifierAlone, keyCode == hold.keyCode, holdKeyIsDown { return nil }
                    break
                }
                if !hold.isModifierAlone, hold.matches(keyCode: keyCode, flags: flags), !holdKeyIsDown {
                    holdKeyIsDown = true
                    holdKeyPressed()
                    return nil  // never type the hotkey into the app
                }
                if !toggle.isModifierAlone, toggle.matches(keyCode: keyCode, flags: flags) {
                    toggleAction()
                    return nil
                }
                if !cancel.isModifierAlone, cancel.matches(keyCode: keyCode, flags: flags), style != .none {
                    cancelAction()
                    return nil
                }

            case .keyUp:
                if !hold.isModifierAlone, keyCode == hold.keyCode, holdKeyIsDown {
                    holdKeyIsDown = false
                    holdKeyReleased()
                    return nil
                }

            default:
                break
            }
            return Unmanaged.passUnretained(event)
        }
    }

    private func holdKeyPressed() {
        switch style {
        case .handsFree:
            // Press while hands-free stops immediately.
            style = .none
            ignoreCurrentPress = true
            pipeline.stopAndProcess()
        case .none:
            ignoreCurrentPress = false
            style = .holdToTalk
            pipeline.startRecording()
        case .holdToTalk:
            break
        }
    }

    private func holdKeyReleased() {
        if ignoreCurrentPress {
            ignoreCurrentPress = false
            return
        }
        // Release always ends a push-to-talk recording. (Recordings shorter
        // than ~0.4 s are discarded by the pipeline, so a stray tap is a
        // no-op.) Hands-free mode is unaffected.
        guard style == .holdToTalk else { return }
        style = .none
        pipeline.stopAndProcess()
    }

    private func toggleAction() {
        switch style {
        case .none:
            style = .handsFree
            pipeline.startRecording()
        case .holdToTalk:
            // Toggle while holding: lock hands-free so the keys can be released.
            style = .handsFree
            ignoreCurrentPress = holdKeyIsDown
        case .handsFree:
            style = .none
            pipeline.stopAndProcess()
        }
    }

    private func cancelAction() {
        style = .none
        pipeline.cancelRecording()
    }
}
