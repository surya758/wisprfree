import Foundation

/// A cleanup/transcription LLM. Two jobs:
/// - clean up a local STT transcript (text → text)
/// - transcribe + clean recorded audio in one shot (WAV → text)
protocol LLMClient {
    func cleanUp(transcript: String, profile: DictationProfile, glossary: [DictionaryEntry]) async throws -> String
    func transcribe(wav: Data, profile: DictationProfile, glossary: [DictionaryEntry]) async throws -> String
}

enum LLMClientFactory {
    static func make(settings: AppSettings) -> LLMClient {
        switch settings.llmProvider {
        case .vertex: return GeminiClient(settings: settings, backend: .vertex)
        case .geminiAPI: return GeminiClient(settings: settings, backend: .geminiAPI)
        case .openAI: return OpenAIClient(settings: settings)
        }
    }
}
