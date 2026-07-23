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
                case .recording, .processing, .confirming: self?.show()
                default: self?.hide()
                }
            }
    }

    private func show() {
        if panel == nil { panel = makePanel() }
        guard let panel else { return }
        position(panel)
        guard !panel.isVisible else { return }
        panel.alphaValue = 0
        panel.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.18
            panel.animator().alphaValue = 1
        }
    }

    private func hide() {
        guard let panel, panel.isVisible else { return }
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.18
            panel.animator().alphaValue = 0
        }, completionHandler: {
            panel.orderOut(nil)
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
        let hosting = NSHostingController(rootView: RecordingCard().environmentObject(AppState.shared))
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

/// Auto-sizing card: waveform + status on top, the transcript below, and a
/// Copy button. Grows with the text (up to a max) and stays screen-centered.
struct RecordingCard: View {
    @EnvironmentObject var appState: AppState

    private static let maxChars = 260

    /// The text to display — live transcript while recording, final while confirming.
    private var text: String {
        switch appState.phase {
        case .confirming: return appState.pendingText
        default: return appState.interimText
        }
    }

    /// Capped to the tail so the latest words stay visible.
    private var displayText: String {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return t.count > Self.maxChars ? "…" + t.suffix(Self.maxChars) : t
    }

    private var status: String {
        switch appState.phase {
        case .recording: return "Listening…"
        case .processing: return "Transcribing…"
        case .confirming: return "Inserting… tap ✕ to cancel"
        default: return ""
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Top row: waveform (or spinner) left, status centered, ✕ right.
            HStack(spacing: 10) {
                if appState.phase == .processing {
                    ProgressView().controlSize(.small).tint(.white).colorScheme(.dark)
                        .frame(width: 60, alignment: .leading)
                } else {
                    WaveformBars(level: appState.audioLevel)
                        .frame(width: 60, alignment: .leading)
                }
                Spacer(minLength: 6)
                Text(status)
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.5))
                Spacer(minLength: 6)
                cancelButton
            }

            if !displayText.isEmpty {
                Text(displayText)
                    .font(.system(size: 15))
                    .foregroundStyle(.white)
                    .lineLimit(4)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            if appState.phase == .confirming {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(.white.opacity(0.15))
                        Capsule().fill(.white.opacity(0.55))
                            .frame(width: geo.size.width * appState.confirmProgress)
                    }
                }
                .frame(height: 4)
            }

            if !displayText.isEmpty {
                HStack {
                    Spacer()
                    Button("Copy") {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(
                            text.trimmingCharacters(in: .whitespacesAndNewlines), forType: .string)
                    }
                    .controlSize(.small)
                }
            }
        }
        .padding(16)
        .frame(width: 460)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.black.opacity(0.82))
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .strokeBorder(.white.opacity(0.12), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.4), radius: 16, y: 6)
        )
    }

    private var cancelButton: some View {
        Button { appState.cancelDictation() } label: {
            Image(systemName: "xmark")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.white.opacity(0.75))
                .frame(width: 22, height: 22)
                .background(Circle().fill(.white.opacity(0.14)))
        }
        .buttonStyle(.plain)
        .help("Cancel")
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
