import AVFoundation
import AppKit

/// Orchestrates one dictation: record → transcribe → clean up → insert.
@MainActor
final class DictationPipeline {
    private let recorder = AudioRecorder()
    private let stt = SttRouter()
    private var processing = false

    /// Preloads the Parakeet model so first dictation is instant.
    func warmUp() async {
        AppState.shared.phase = .loadingModel
        do {
            try await stt.prepare()
            AppState.shared.phase = .idle
        } catch {
            fail("Speech model download failed: \(error.localizedDescription)")
        }
    }

    /// Discards the current recording without transcribing.
    func cancelRecording() {
        guard recorder.isRecording else { return }
        _ = recorder.stop()
        AppState.shared.audioLevel = 0
        AppState.shared.phase = .idle
    }

    func startRecording() {
        guard !recorder.isRecording, !processing else { return }
        recorder.onLevel = { level in
            DispatchQueue.main.async { AppState.shared.audioLevel = level }
        }
        Task {
            guard await ensureMicPermission() else {
                fail(WisprError.micPermissionDenied.localizedDescription)
                return
            }
            do {
                try recorder.start()
                AppState.shared.phase = .recording
            } catch {
                fail(error.localizedDescription)
            }
        }
    }

    func stopAndProcess() {
        guard recorder.isRecording else { return }
        let samples = recorder.stop()
        AppState.shared.audioLevel = 0
        // Ignore accidental taps (< 0.4 s of audio).
        guard samples.count > Int(AudioRecorder.targetSampleRate * 0.4) else {
            AppState.shared.phase = .idle
            return
        }

        processing = true
        AppState.shared.phase = .processing
        Task {
            defer { processing = false }
            let settings = AppSettings.current
            let profile = settings.profile
            let glossary = profile.usesGlossary ? DictionaryStore.shared.entries : []
            let gemini = GeminiClient(settings: settings)
            var raw = ""

            do {
                let text: String
                switch settings.mode {
                case .parakeetOnly:
                    raw = try await stt.transcribe(samples)
                    text = raw
                case .directGemini:
                    text = try await gemini.transcribe(
                        wav: AudioRecorder.wavData(from: samples),
                        profile: profile,
                        glossary: glossary
                    )
                case .parakeetGemini:
                    raw = try await stt.transcribe(samples)
                    guard !raw.isEmpty else {
                        AppState.shared.phase = .idle
                        return
                    }
                    do {
                        text = try await gemini.cleanUp(transcript: raw, profile: profile, glossary: glossary)
                    } catch where settings.fallbackToRaw {
                        // Offline or API failure: better raw text than lost dictation.
                        notify("Gemini unavailable — inserted raw transcript",
                               detail: error.localizedDescription)
                        text = raw
                    }
                }

                guard !text.isEmpty else {
                    AppState.shared.phase = .idle
                    return
                }
                HistoryStore.shared.add(text: text, raw: raw, mode: settings.mode)
                AppState.shared.lastResult = text
                try TextInserter.insert(text)
                AppState.shared.phase = .idle
                AppState.shared.lastError = nil
            } catch {
                // Never lose words: keep the raw transcript on the clipboard.
                if !raw.isEmpty {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(raw, forType: .string)
                }
                fail(error.localizedDescription)
            }
        }
    }

    private func ensureMicPermission() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized: return true
        case .notDetermined: return await AVCaptureDevice.requestAccess(for: .audio)
        default: return false
        }
    }

    private func fail(_ message: String) {
        AppState.shared.lastError = message
        AppState.shared.phase = .error
        notify("Dictation failed", detail: message)
    }

    private func notify(_ title: String, detail: String) {
        let notification = NSUserNotification()
        notification.title = title
        notification.informativeText = detail
        NSUserNotificationCenter.default.deliver(notification)
    }
}
