import Foundation

enum WisprError: LocalizedError {
    case noMicrophone
    case micPermissionDenied
    case modelNotLoaded
    case recordingTooShort
    case auth(String)
    case gemini(String)
    case llm(String)
    case accessibilityDenied

    var errorDescription: String? {
        switch self {
        case .noMicrophone:
            return "No microphone available."
        case .micPermissionDenied:
            return "Microphone access denied. Enable it in System Settings → Privacy & Security → Microphone."
        case .modelNotLoaded:
            return "Speech model is not loaded yet."
        case .recordingTooShort:
            return "Recording too short."
        case .auth(let detail):
            return "Google auth: \(detail)"
        case .gemini(let detail):
            return "Gemini: \(detail)"
        case .llm(let detail):
            return "LLM: \(detail)"
        case .accessibilityDenied:
            return "Accessibility access needed to type into other apps. Enable WisprFree in System Settings → Privacy & Security → Accessibility."
        }
    }
}
