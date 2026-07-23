import Foundation

/// Calls Gemini on Vertex AI (generateContent) for two jobs:
/// - cleaning up a Parakeet transcript (text in, text out)
/// - transcribing + cleaning recorded audio in one shot (WAV in, text out)
struct GeminiClient {
    let settings: AppSettings

    private var endpoint: URL {
        let project = settings.gcpProject
        let location = settings.gcpLocation
        let model = settings.model
        let host = location == "global" ? "aiplatform.googleapis.com" : "\(location)-aiplatform.googleapis.com"
        return URL(string: "https://\(host)/v1/projects/\(project)/locations/\(location)/publishers/google/models/\(model):generateContent")!
    }

    func cleanUp(transcript: String, profile: DictationProfile, glossary: [DictionaryEntry]) async throws -> String {
        let body = requestBody(
            systemPrompt: PromptBuilder.cleanupSystemPrompt(profile: profile, glossary: glossary),
            parts: [["text": transcript]]
        )
        return try await send(body)
    }

    func transcribe(wav: Data, profile: DictationProfile, glossary: [DictionaryEntry]) async throws -> String {
        let body = requestBody(
            systemPrompt: PromptBuilder.directSystemPrompt(profile: profile, glossary: glossary),
            parts: [
                ["inlineData": ["mimeType": "audio/wav", "data": wav.base64EncodedString()]],
                ["text": "Transcribe and clean up this dictation."],
            ]
        )
        return try await send(body)
    }

    private func requestBody(systemPrompt: String, parts: [[String: Any]]) -> [String: Any] {
        var generationConfig: [String: Any] = [
            "temperature": 0.2,
            "maxOutputTokens": 8192,
        ]
        // Gemini 3 models spend output budget on "thinking"; dictation cleanup
        // needs speed, not deliberation.
        if settings.model.hasPrefix("gemini-3") {
            generationConfig["thinkingConfig"] = ["thinkingLevel": "LOW"]
        }
        // Novel prose (fight scenes etc.) can trip default safety filters.
        let safetySettings = [
            "HARM_CATEGORY_HARASSMENT",
            "HARM_CATEGORY_HATE_SPEECH",
            "HARM_CATEGORY_SEXUALLY_EXPLICIT",
            "HARM_CATEGORY_DANGEROUS_CONTENT",
        ].map { ["category": $0, "threshold": "BLOCK_NONE"] }

        return [
            "systemInstruction": ["parts": [["text": systemPrompt]]],
            "contents": [["role": "user", "parts": parts]],
            "generationConfig": generationConfig,
            "safetySettings": safetySettings,
        ]
    }

    private func send(_ body: [String: Any]) async throws -> String {
        let token = try await GoogleAuth.shared.accessToken()
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 60
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw WisprError.gemini("No response") }
        guard http.statusCode == 200 else {
            let detail = String(data: data, encoding: .utf8)?.prefix(500) ?? ""
            throw WisprError.gemini("HTTP \(http.statusCode): \(detail)")
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw WisprError.gemini("Unparseable response")
        }
        let candidates = json["candidates"] as? [[String: Any]] ?? []
        let parts = ((candidates.first?["content"] as? [String: Any])?["parts"] as? [[String: Any]]) ?? []
        let text = parts.compactMap { $0["text"] as? String }.joined()
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if text.isEmpty {
            let finishReason = candidates.first?["finishReason"] as? String
            let blockReason = (json["promptFeedback"] as? [String: Any])?["blockReason"] as? String
            throw WisprError.gemini(blockReason.map { "Prompt blocked: \($0)" }
                ?? finishReason.map { "No text (finishReason: \($0))" }
                ?? "Empty response")
        }
        return text
    }
}
