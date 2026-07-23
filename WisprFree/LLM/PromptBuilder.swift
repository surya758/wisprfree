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

    /// The style rules actually used: the user's in-app edit if present,
    /// otherwise the built-in default.
    static func effectiveStyleRules(_ profile: DictationProfile) -> String {
        AppSettings.current.customPrompt(for: profile) ?? defaultStyleRules(profile)
    }

    /// Built-in style instructions. The speaker is a non-native English
    /// speaker in every profile; how hard to clean differs.
    static func defaultStyleRules(_ profile: DictationProfile) -> String {
        switch profile {
        case .casual:
            return """
            The speaker is dictating everyday text — chat messages, quick notes, \
            searches, short emails. Clean LIGHTLY:
            - Remove filler words ("um", "uh"), false starts, and stutter repeats.
            - Fix only clear grammar slips; otherwise keep the speaker's exact \
            wording, casual tone, and sentence rhythm.
            - Do NOT formalize, embellish, restructure, or expand anything.
            """
        case .writing:
            return """
            The speaker is a novelist dictating fiction prose. The raw transcript \
            contains pauses, filler words, false starts, and grammar slips. Clean \
            THOROUGHLY:
            - Fix grammar fully and remove all fillers and false starts.
            - Preserve the speaker's meaning, tone, and voice. Do NOT add new \
            content, do NOT summarize, do NOT continue the story.
            - Keep sentence order; only merge fragments that are clearly one sentence.
            """
        case .professional:
            return """
            The speaker is dictating professional text — work emails, documents, \
            reports. Produce clear, well-punctuated, grammatical prose:
            - Remove fillers and false starts; fix grammar properly.
            - Tighten wording slightly where dictation rambles, but keep every \
            point the speaker makes. Do NOT add content or change meaning.
            """
        }
    }

    static func cleanupSystemPrompt(profile: DictationProfile, glossary: [DictionaryEntry]) -> String {
        """
        You clean up text dictated by a non-native English speaker. The raw \
        transcript comes from speech-to-text.

        \(effectiveStyleRules(profile))

        Always:
        - Spoken punctuation commands ("comma", "new line", "new paragraph") become \
        the actual punctuation/formatting.
        - Output ONLY the cleaned text — no preamble, no quotes, no explanations.
        \(profile.usesGlossary ? glossarySection(glossary) : "")
        """
    }

    static func directSystemPrompt(profile: DictationProfile, glossary: [DictionaryEntry]) -> String {
        """
        You transcribe dictation audio from a non-native English speaker, then \
        clean it up in one pass.

        \(effectiveStyleRules(profile))

        Always:
        - Transcribe what is said, then apply the cleanup rules above.
        - Spoken punctuation commands ("comma", "new line", "new paragraph") become \
        the actual punctuation/formatting.
        - Output ONLY the cleaned transcription — no preamble, no quotes, no timestamps.
        \(profile.usesGlossary ? glossarySection(glossary) : "")
        """
    }
}
