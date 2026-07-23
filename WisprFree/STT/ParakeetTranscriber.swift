import Foundation
import FluidAudio

/// NVIDIA Parakeet TDT via FluidAudio (CoreML, Apple Neural Engine).
/// Models are downloaded once (~460 MB) and cached by FluidAudio.
actor ParakeetTranscriber: SpeechToText {
    private let versionId: String
    private var manager: AsrManager?

    init(versionId: String) {
        self.versionId = versionId
    }

    private var version: AsrModelVersion {
        versionId == "v2" ? .v2 : .v3
    }

    func prepare() async throws {
        guard manager == nil else { return }
        let models = try await AsrModels.downloadAndLoad(
            version: version,
            progressHandler: { progress in SttProgress.report(progress.fractionCompleted) }
        )
        let asr = AsrManager(config: .default)
        try await asr.loadModels(models)
        manager = asr
    }

    func transcribe(_ samples: [Float]) async throws -> String {
        try await prepare()
        guard let manager else { throw WisprError.modelNotLoaded }
        var state = try TdtDecoderState(decoderLayers: await manager.decoderLayerCount)
        let result = try await manager.transcribe(samples, decoderState: &state)
        return result.text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
