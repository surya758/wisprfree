import Foundation
import WhisperKit

/// OpenAI Whisper via WhisperKit (CoreML). Models are downloaded from
/// HuggingFace on first use and cached by WhisperKit.
actor WhisperTranscriber: SpeechToText {
    private let model: String
    private var whisper: WhisperKit?

    init(model: String) {
        self.model = model
    }

    func prepare() async throws {
        guard whisper == nil else { return }
        // Download first (skips already-cached files) so we get real progress,
        // then load from the resolved folder.
        let folder = try await WhisperKit.download(
            variant: model,
            progressCallback: { progress in SttProgress.report(progress.fractionCompleted) }
        )
        let config = WhisperKitConfig(model: model, modelFolder: folder.path)
        whisper = try await WhisperKit(config)
    }

    func transcribe(_ samples: [Float]) async throws -> String {
        try await prepare()
        guard let whisper else { throw WisprError.modelNotLoaded }
        let results = try await whisper.transcribe(audioArray: samples)
        return results.map(\.text).joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
