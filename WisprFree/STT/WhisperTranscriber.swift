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
        let config = WhisperKitConfig(model: model)
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
