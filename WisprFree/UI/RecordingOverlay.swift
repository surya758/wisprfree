import SwiftUI
import AppKit
import Combine

/// Floating pill at the bottom-center of the screen while recording/processing,
/// like most dictation apps. Click-through, joins all Spaces and full-screen apps.
@MainActor
final class RecordingOverlayController {
    private var panel: NSPanel?
    private var cancellable: AnyCancellable?

    init(appState: AppState) {
        cancellable = appState.$phase
            .receive(on: DispatchQueue.main)
            .sink { [weak self] phase in
                switch phase {
                case .recording, .processing, .confirming:
                    AppState.shared.overlayPhase = phase
                    self?.show()
                default:
                    // Keep overlayPhase at its last active value so the fade-out
                    // doesn't flash the recording pill.
                    self?.hide()
                }
            }
    }

    private static let slide: CGFloat = 26

    private func show() {
        if panel == nil { panel = makePanel() }
        guard let panel else { return }
        position(panel)
        guard !panel.isVisible else { return }
        // Slide up from below while fading in.
        let target = panel.frame.origin
        panel.setFrameOrigin(NSPoint(x: target.x, y: target.y - Self.slide))
        panel.alphaValue = 0
        panel.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.24
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().alphaValue = 1
            panel.animator().setFrameOrigin(target)
        }
    }

    private func hide() {
        guard let panel, panel.isVisible else { return }
        // Slide down off the bottom while fading out.
        let origin = panel.frame.origin
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.22
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            panel.animator().alphaValue = 0
            panel.animator().setFrameOrigin(NSPoint(x: origin.x, y: origin.y - Self.slide))
        }, completionHandler: {
            panel.orderOut(nil)
            panel.setFrameOrigin(origin)
        })
    }

    private func makePanel() -> NSPanel {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 460, height: 60),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .statusBar
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        // Mouse events stay on so the buttons are clickable; the panel is
        // non-activating, so clicks don't steal focus from the target app.
        panel.ignoresMouseEvents = false
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]

        // contentViewController auto-sizes the window to the SwiftUI card, so
        // it grows with the transcript; re-center on every resize.
        let hosting = NSHostingController(rootView: RecordingOverlayView().environmentObject(AppState.shared))
        hosting.sizingOptions = .preferredContentSize
        panel.contentViewController = hosting
        NotificationCenter.default.addObserver(
            forName: NSWindow.didResizeNotification, object: panel, queue: .main
        ) { [weak self, weak panel] _ in
            guard let panel else { return }
            MainActor.assumeIsolated { self?.position(panel) }
        }
        return panel
    }

    private func position(_ panel: NSPanel) {
        // Screen with the focused window (where text will be inserted), else main.
        let screen = NSScreen.screens.first { $0.frame.contains(NSEvent.mouseLocation) }
            ?? NSScreen.main
        guard let screen else { return }
        let frame = screen.visibleFrame
        let size = panel.frame.size
        panel.setFrameOrigin(NSPoint(
            x: frame.midX - size.width / 2,
            y: frame.minY + 16
        ))
    }
}

/// Layered overlay: a text-only box (only when live transcription is on / during
/// the grace window) sits above a compact control pill.
struct RecordingOverlayView: View {
    @EnvironmentObject var appState: AppState

    private var showTextBox: Bool {
        // Only for live transcription — the grace window uses the pill alone.
        appState.overlayPhase == .recording && AppSettings.current.liveTranscription
    }

    var body: some View {
        VStack(spacing: 8) {
            if showTextBox {
                TranscriptBox()
            }
            ControlPill()
        }
        .padding(.bottom, 2)
    }
}

/// The big top box — text only. No logo, buttons, or waveform.
struct TranscriptBox: View {
    @EnvironmentObject var appState: AppState
    private static let maxChars = 280

    private var text: String { appState.interimText }

    private var display: String {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.isEmpty { return "Listening…" }
        return t.count > Self.maxChars ? "…" + t.suffix(Self.maxChars) : t
    }

    private var isPlaceholder: Bool {
        text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        Text(display)
            .font(.system(size: 15))
            .foregroundStyle(.white.opacity(isPlaceholder ? 0.45 : 0.95))
            .lineLimit(4)
            .fixedSize(horizontal: false, vertical: true)
            .frame(width: 420, alignment: .leading)
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color.black.opacity(0.82))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .strokeBorder(.white.opacity(0.12), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.4), radius: 16, y: 6)
            )
    }
}

/// The compact bottom pill — three elements: state indicator + waveform + ✕.
struct ControlPill: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        HStack(spacing: 10) {
            switch appState.overlayPhase {
            case .processing:
                ProgressView().controlSize(.small).tint(.white).colorScheme(.dark)
                WaveformBars(level: 0)
                cancelButton
            case .confirming:
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green).font(.system(size: 13))
                CountdownBar()
                cancelButton
            default:  // recording
                Circle().fill(.red).frame(width: 8, height: 8)
                WaveformBars(level: appState.audioLevel)
                cancelButton
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(Color.black.opacity(0.82))
                .overlay(Capsule().strokeBorder(.white.opacity(0.12), lineWidth: 1))
                .shadow(color: .black.opacity(0.35), radius: 12, y: 4)
        )
    }

    private var cancelButton: some View {
        Button { appState.cancelDictation() } label: {
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 15))
                .foregroundStyle(.white.opacity(0.65))
        }
        .buttonStyle(.plain)
        .help("Cancel")
    }
}

/// Draining countdown for the grace window. Animates from onAppear — i.e.
/// once it's actually on screen — so the motion is always visible.
struct CountdownBar: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        ZStack(alignment: .leading) {
            Capsule().fill(.white.opacity(0.15))
            GeometryReader { geo in
                Capsule().fill(.white.opacity(0.55))
                    .frame(width: geo.size.width * appState.confirmProgress)
            }
        }
        .frame(width: 60, height: 4)
        .onAppear {
            appState.confirmProgress = 1
            withAnimation(.linear(duration: max(0.1, AppSettings.current.insertDelay))) {
                appState.confirmProgress = 0
            }
        }
    }
}

struct WaveformBars: View {
    var level: Float
    private let barCount = 14

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate
            HStack(spacing: 3) {
                ForEach(0..<barCount, id: \.self) { index in
                    Capsule()
                        .fill(.white.opacity(0.92))
                        .frame(width: 1.5, height: barHeight(index: index, time: time))
                }
            }
            .animation(.linear(duration: 0.1), value: level)
        }
        .frame(height: 20)
    }

    private func barHeight(index: Int, time: TimeInterval) -> CGFloat {
        // Each bar wobbles on its own phase; amplitude follows the mic level
        // so the wave visibly reacts to speech.
        let phase = time * 7 + Double(index) * 0.9
        let wobble = (sin(phase) + sin(phase * 1.7 + 1.3)) / 2 // -1…1
        let amplitude = CGFloat(max(0.12, min(1, level * 1.6)))
        return 4 + (10 + 9 * wobble) * amplitude
    }
}

struct ProcessingDots: View {
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 20.0)) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate
            HStack(spacing: 4) {
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .fill(.white)
                        .frame(width: 6, height: 6)
                        .opacity(0.35 + 0.65 * max(0, sin(time * 4 - Double(index) * 0.7)))
                }
            }
        }
    }
}
