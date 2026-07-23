import AVFoundation
import AppKit

/// Orchestrates one dictation: record → transcribe → clean up → insert.
@MainActor
final class DictationPipeline {
    private let recorder = AudioRecorder()
    private let stt = SttRouter()
    private var processing = false
    private var processingTask: Task<Void, Never>?
    private var liveTask: Task<Void, Never>?

    /// True while recording or transcribing — used to decide whether the
    /// cancel key should be captured.
    var isBusy: Bool { recorder.isRecording || processing }

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

    /// Aborts whatever is in flight — the recording, or an in-progress
    /// transcription/cleanup (which cancels the network request too).
    func cancel() {
        if recorder.isRecording {
            _ = recorder.stop()
            AppState.shared.audioLevel = 0
        }
        stopLivePreview()
        processingTask?.cancel()
        processingTask = nil
        processing = false
        AppState.shared.phase = .idle
    }

    // MARK: Live preview

    /// While recording, periodically re-transcribe the buffer so far with the
    /// local model and show it in the overlay. Cheap because Parakeet runs at
    /// ~100× realtime; the final transcription still happens on stop.
    private func startLivePreview() {
        AppState.shared.interimText = ""
        liveTask = Task { [stt, recorder] in
            // Only transcribe the recent tail so each pass stays fast even on
            // long dictations — the final transcription uses the full buffer.
            let window = Int(AudioRecorder.targetSampleRate * 18)
            while !Task.isCancelled, recorder.isRecording {
                try? await Task.sleep(for: .milliseconds(650))
                guard !Task.isCancelled, recorder.isRecording else { break }
                let snap = recorder.snapshot()
                guard snap.count > Int(AudioRecorder.targetSampleRate * 0.3) else { continue }
                let recent = snap.count > window ? Array(snap.suffix(window)) : snap
                if let text = try? await stt.transcribe(recent),
                   !text.isEmpty, !Task.isCancelled, recorder.isRecording {
                    AppState.shared.interimText = text
                }
            }
        }
    }

    private func stopLivePreview() {
        liveTask?.cancel()
        liveTask = nil
        AppState.shared.interimText = ""
    }

    /// Counts down the insert-delay grace period, updating the overlay.
    /// Returns false if the dictation was cancelled during the window.
    private func graceWindow(text: String) async -> Bool {
        let delay = AppSettings.current.insertDelay
        guard delay > 0 else { return !Task.isCancelled }

        AppState.shared.pendingText = text
        AppState.shared.confirmProgress = 1
        AppState.shared.phase = .confirming
        // The countdown bar animates itself from onAppear (see CountdownBar),
        // once it's actually on screen — here we just wait out the window.
        try? await Task.sleep(for: .seconds(delay))
        return !Task.isCancelled
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
                Sound.playStart()
                if AppSettings.current.liveTranscription { startLivePreview() }
            } catch {
                fail(error.localizedDescription)
            }
        }
    }

    func stopAndProcess() {
        guard recorder.isRecording else { return }
        let samples = recorder.stop()
        stopLivePreview()
        AppState.shared.audioLevel = 0
        // Ignore accidental taps (< 0.4 s of audio).
        guard samples.count > Int(AudioRecorder.targetSampleRate * 0.4) else {
            AppState.shared.phase = .idle
            return
        }
        Sound.playStop()

        processing = true
        AppState.shared.phase = .processing
        processingTask = Task {
            defer { processing = false; processingTask = nil }
            let settings = AppSettings.current
            let profile = settings.profile
            let glossary = profile.usesGlossary ? DictionaryStore.shared.entries : []
            let llm = LLMClientFactory.make(settings: settings)
            var raw = ""

            do {
                let text: String
                switch settings.mode {
                case .parakeetOnly:
                    raw = try await stt.transcribe(samples)
                    text = raw
                case .directGemini:
                    text = try await llm.transcribe(
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
                        text = try await llm.cleanUp(transcript: raw, profile: profile, glossary: glossary)
                    } catch where settings.fallbackToRaw && !Task.isCancelled {
                        // Offline or API failure: better raw text than lost dictation.
                        notify("AI model unavailable — inserted raw transcript",
                               detail: error.localizedDescription)
                        text = raw
                    }
                }

                // Cancelled mid-flight (cancel key / ✕): drop it silently.
                if Task.isCancelled {
                    AppState.shared.phase = .idle
                    return
                }
                guard !text.isEmpty else {
                    AppState.shared.phase = .idle
                    return
                }

                // Grace window: last chance to cancel (X / cancel key) before
                // the text lands. Skipped when the delay is 0.
                if !(await graceWindow(text: text)) {
                    AppState.shared.phase = .idle
                    return
                }

                HistoryStore.shared.add(text: text, raw: raw, mode: settings.mode)
                StatsStore.shared.record(
                    text: text,
                    audioSeconds: Double(samples.count) / AudioRecorder.targetSampleRate
                )
                AppState.shared.lastResult = text
                try TextInserter.insert(text)
                AppState.shared.phase = .idle
                AppState.shared.lastError = nil
            } catch {
                if Task.isCancelled {
                    AppState.shared.phase = .idle
                    return
                }
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
