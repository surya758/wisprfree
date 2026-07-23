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
        let phase = AppState.shared.phase
        // Two-tier (taller/wider) when there's a text row: live preview or the
        // grace window. Otherwise a compact single row.
        let tiered = phase == .confirming
            || (phase == .recording && AppSettings.current.liveTranscription)
        panel.setContentSize(NSSize(width: tiered ? 460 : 250, height: tiered ? 62 : 40))
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
            contentRect: NSRect(x: 0, y: 0, width: 250, height: 40),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .statusBar
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        // Mouse events stay on so the ✕ button is clickable; the panel is
        // non-activating, so clicks don't steal focus from the target app.
        panel.ignoresMouseEvents = false
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.contentView = NSHostingView(rootView: RecordingPill().environmentObject(AppState.shared))
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

/// The pill itself: animated waveform bars while recording (driven by mic
/// level), pulsing dots while transcribing.
struct RecordingPill: View {
    @EnvironmentObject var appState: AppState

    private var isLiveRecording: Bool {
        appState.phase == .recording && AppSettings.current.liveTranscription
    }

    var body: some View {
        Group {
            switch appState.phase {
            case .confirming: confirming
            case .recording where isLiveRecording: liveRecording
            case .recording: simpleRow
            default: processingRow
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, isLiveRecording || appState.phase == .confirming ? 9 : 8)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.black.opacity(0.78))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(.white.opacity(0.12), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.35), radius: 12, y: 4)
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// Compact single row: red dot + waveform + ✕.
    private var simpleRow: some View {
        HStack(spacing: 10) {
            Circle().fill(.red).frame(width: 8, height: 8)
            WaveformBars(level: appState.audioLevel)
            Spacer(minLength: 0)
            cancelButton
        }
    }

    private var processingRow: some View {
        HStack(spacing: 10) {
            ProgressView().controlSize(.small).tint(.white).colorScheme(.dark)
            Spacer(minLength: 0)
            cancelButton
        }
    }

    /// Two tiers: transcribed text on top, waveform + ✕ on the bottom.
    private var liveRecording: some View {
        VStack(spacing: 7) {
            Text(appState.interimText.isEmpty ? "Listening…" : appState.interimText)
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(appState.interimText.isEmpty ? 0.5 : 0.95))
                .lineLimit(1)
                .truncationMode(.head)
                .frame(maxWidth: .infinity, alignment: .leading)
            HStack(spacing: 10) {
                Circle().fill(.red).frame(width: 8, height: 8)
                WaveformBars(level: appState.audioLevel)
                Spacer(minLength: 0)
                cancelButton
            }
        }
    }

    /// Grace window: the pending text and a draining countdown bar.
    private var confirming: some View {
        VStack(spacing: 7) {
            HStack(spacing: 10) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.system(size: 13))
                Text(appState.pendingText)
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.95))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity, alignment: .leading)
                cancelButton
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.15))
                    Capsule().fill(.white.opacity(0.55))
                        .frame(width: geo.size.width * appState.confirmProgress)
                }
            }
            .frame(height: 4)
        }
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
