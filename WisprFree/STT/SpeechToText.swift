import Foundation

/// A local speech-to-text engine: loads its model (downloading on first use)
/// and transcribes 16 kHz mono Float32 samples.
protocol SpeechToText: Actor {
    func prepare() async throws
    func transcribe(_ samples: [Float]) async throws -> String
}

/// Routes to the engine selected in Settings, rebuilding it when the
/// selection changes. Dropping the old engine frees its models.
actor SttRouter {
    private var engine: (any SpeechToText)?
    private var loadedId: String?

    private static func make(_ id: String) -> any SpeechToText {
        switch id {
        case "parakeet-v3": return ParakeetTranscriber(versionId: "v3")
        case "whisper-large-v3": return WhisperTranscriber(model: "large-v3")
        case "cohere-transcribe": return CohereTranscriber()
        default: return ParakeetTranscriber(versionId: "v2")
        }
    }

    func prepare() async throws {
        let id = AppSettings.current.sttModel
        if engine == nil || loadedId != id {
            engine = Self.make(id)
            loadedId = id
        }
        try await engine!.prepare()
    }

    func transcribe(_ samples: [Float]) async throws -> String {
        try await prepare()
        guard let engine else { throw WisprError.modelNotLoaded }
        return try await engine.transcribe(samples)
    }
}
