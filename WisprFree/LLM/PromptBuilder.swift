import Foundation

enum PromptBuilder {
    private static func glossarySection(_ glossary: [DictionaryEntry]) -> String {
        guard !glossary.isEmpty else { return "" }
        let lines = glossary.map { entry in
            entry.hint.isEmpty
                ? "- \(entry.term)"
                : "- \(entry.term) (may be misheard as: \(entry.hint))"
        }
        return """

        GLOSSARY — proper nouns the speaker uses often (novel character/place names, \
        many in Chinese pinyin). If any word or phrase in the dictation sounds like one \
        of these, replace it with the exact glossary spelling:
        \(lines.joined(separator: "\n"))
        """
    }

    static func cleanupSystemPrompt(glossary: [DictionaryEntry]) -> String {
        """
        You clean up dictated text from a novelist who is a non-native English speaker. \
        The raw transcript comes from speech-to-text and contains pauses, filler words, \
        false starts, repeated words, and grammar slips.

        Rules:
        - Fix grammar and remove fillers ("um", "uh", "you know") and false starts.
        - Preserve the speaker's meaning, tone, and voice. Do NOT add new content, \
        do NOT summarize, do NOT continue the story.
        - Keep sentence order; only merge fragments that are clearly one sentence.
        - Spoken punctuation commands ("comma", "new line", "new paragraph") become \
        the actual punctuation/formatting.
        - Output ONLY the cleaned text — no preamble, no quotes, no explanations.
        \(glossarySection(glossary))
        """
    }

    static func directSystemPrompt(glossary: [DictionaryEntry]) -> String {
        """
        You transcribe dictation audio from a novelist who is a non-native English \
        speaker, then clean it up in one pass.

        Rules:
        - Transcribe what is said, then fix grammar and remove filler words \
        ("um", "uh"), false starts, and repeated words caused by pauses.
        - Preserve the speaker's meaning, tone, and voice. Do NOT add new content, \
        do NOT summarize, do NOT continue the story.
        - Spoken punctuation commands ("comma", "new line", "new paragraph") become \
        the actual punctuation/formatting.
        - Output ONLY the cleaned transcription — no preamble, no quotes, no timestamps.
        \(glossarySection(glossary))
        """
    }
}
