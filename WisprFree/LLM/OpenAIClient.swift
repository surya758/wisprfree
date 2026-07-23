import Foundation

/// Chat-completions client for OpenAI and OpenAI-compatible endpoints
/// (OpenRouter, Groq, local Ollama, …) — base URL and model are settings.
/// Direct-audio mode sends `input_audio` content, which needs an
/// audio-capable model (e.g. gpt-4o-audio / gpt-audio).
struct OpenAIClient: LLMClient {
    let settings: AppSettings

    func cleanUp(transcript: String, profile: DictationProfile, glossary: [DictionaryEntry]) async throws -> String {
        try await send(
            systemPrompt: PromptBuilder.cleanupSystemPrompt(profile: profile, glossary: glossary),
            userContent: transcript
        )
    }

    func transcribe(wav: Data, profile: DictationProfile, glossary: [DictionaryEntry]) async throws -> String {
        try await send(
            systemPrompt: PromptBuilder.directSystemPrompt(profile: profile, glossary: glossary),
            userContent: [
                [
                    "type": "input_audio",
                    "input_audio": ["data": wav.base64EncodedString(), "format": "wav"],
                ],
                ["type": "text", "text": "Transcribe and clean up this dictation."],
            ]
        )
    }

    /// `userContent` is a plain string or an array of content parts.
    private func send(systemPrompt: String, userContent: Any) async throws -> String {
        guard let key = settings.openaiAPIKey, !key.isEmpty else {
            throw WisprError.auth("No OpenAI API key. Add one in Settings → Models.")
        }
        let base = settings.openaiBaseURL.hasSuffix("/")
            ? String(settings.openaiBaseURL.dropLast())
            : settings.openaiBaseURL
        guard let url = URL(string: "\(base)/chat/completions") else {
            throw WisprError.llm("Invalid base URL: \(settings.openaiBaseURL)")
        }

        // Minimal body for maximum cross-provider compatibility — no
        // temperature or token caps (some models reject non-default values).
        let body: [String: Any] = [
            "model": settings.openaiModel,
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": userContent],
            ],
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 60
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw WisprError.llm("No response") }
        guard http.statusCode == 200 else {
            let detail = String(data: data, encoding: .utf8)?.prefix(500) ?? ""
            throw WisprError.llm("HTTP \(http.statusCode): \(detail)")
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let message = choices.first?["message"] as? [String: Any] else {
            throw WisprError.llm("Unparseable response")
        }
        let text = (message["content"] as? String ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            throw WisprError.llm("Empty response (finish: \(choices.first?["finish_reason"] ?? "?"))")
        }
        return text
    }
}
