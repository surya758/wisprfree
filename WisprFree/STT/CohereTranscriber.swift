import Foundation
import FluidAudio

/// Cohere Transcribe (03-2026, q8) via FluidAudio CoreML. Downloaded from
/// HuggingFace on first use into the FluidAudio model cache.
actor CohereTranscriber: SpeechToText {
    private let pipeline = CoherePipeline()
    private var models: CoherePipeline.LoadedModels?

    private var modelDirectory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("FluidAudio/Models", isDirectory: true)
            .appendingPathComponent(Repo.cohereTranscribeCoreml.folderName, isDirectory: true)
    }

    func prepare() async throws {
        guard models == nil else { return }
        let dir = modelDirectory
        let missing = ModelNames.CohereTranscribe.requiredModels.filter {
            !FileManager.default.fileExists(atPath: dir.appendingPathComponent($0).path)
        }
        if !missing.isEmpty {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            try await ModelHub.download(.cohereTranscribeCoreml, to: dir)
        }
        models = try await CoherePipeline.loadModels(
            encoderDir: dir, decoderDir: dir, vocabDir: dir)
    }

    func transcribe(_ samples: [Float]) async throws -> String {
        try await prepare()
        guard let models else { throw WisprError.modelNotLoaded }
        let result = try await pipeline.transcribeLong(audio: samples, models: models)
        return result.text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
