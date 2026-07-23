import Foundation
import CoreGraphics

enum DictationMode: String, CaseIterable, Identifiable {
    case parakeetGemini
    case directGemini
    case parakeetOnly

    var id: String { rawValue }

    var label: String {
        switch self {
        case .parakeetGemini: return "Local model + Gemini cleanup"
        case .directGemini: return "Audio directly to Gemini"
        case .parakeetOnly: return "Local model only (raw, offline)"
        }
    }
}

/// A recorded global hotkey: a key (possibly a bare modifier like Fn) plus
/// required modifier flags (e.g. Fn+Space).
struct HotkeyBinding: Codable, Equatable {
    var keyCode: Int
    /// Device-independent modifier bits (⌘⌥⌃⇧ + fn), NSEvent/CGEvent-compatible.
    var flags: UInt64
    var label: String

    static let commandMask: UInt64 = 0x100000
    static let optionMask: UInt64 = 0x80000
    static let controlMask: UInt64 = 0x40000
    static let shiftMask: UInt64 = 0x20000
    static let fnMask: UInt64 = 0x800000
    /// The ⌘⌥⌃⇧ bits, compared exactly when matching events.
    static let strictMask: UInt64 = commandMask | optionMask | controlMask | shiftMask

    /// Keycode → flag bit for keys that are themselves modifiers.
    static let modifierMasks: [Int: UInt64] = [
        63: fnMask,
        54: commandMask, 55: commandMask,
        58: optionMask, 61: optionMask,
        59: controlMask, 62: controlMask,
        56: shiftMask, 60: shiftMask,
    ]

    /// True when the "key" is a bare modifier (Fn, Right ⌘, …), which arrives
    /// as flagsChanged events instead of keyDown/keyUp.
    var isModifierAlone: Bool { Self.modifierMasks[keyCode] != nil }

    static let defaultHold = HotkeyBinding(keyCode: 63, flags: fnMask, label: "Fn")
    static let defaultToggle = HotkeyBinding(keyCode: 49, flags: fnMask, label: "Fn + Space")
    static let defaultCancel = HotkeyBinding(keyCode: 53, flags: 0, label: "Esc")

    /// Does a key event (keycode + live flags) match this binding?
    func matches(keyCode eventKeyCode: Int, flags eventFlags: UInt64) -> Bool {
        guard eventKeyCode == keyCode else { return false }
        // ⌘⌥⌃⇧ must match exactly (so plain Space ≠ ⌘Space)…
        guard (eventFlags & Self.strictMask) == (flags & Self.strictMask) else { return false }
        // …but fn is only *required*, never forbidden: macOS sets the fn bit
        // on its own for F-keys and arrows.
        if flags & Self.fnMask != 0, eventFlags & Self.fnMask == 0 { return false }
        return true
    }
}

/// Local speech-recognition engines/models the app can download and run.
enum SttCatalog {
    struct Option: Identifiable {
        let id: String
        let label: String
        let detail: String
    }

    static let options: [Option] = [
        Option(id: "parakeet-v2", label: "Parakeet TDT v2 · 0.6B",
               detail: "NVIDIA — English, fast and accurate (default)"),
        Option(id: "parakeet-v3", label: "Parakeet TDT v3 · 0.6B",
               detail: "NVIDIA — multilingual (25 languages)"),
        Option(id: "whisper-large-v3", label: "Whisper Large v3",
               detail: "OpenAI — multilingual, strongest accuracy, slower (~3 GB)"),
        Option(id: "cohere-transcribe", label: "Cohere Transcribe",
               detail: "Cohere — multilingual incl. Chinese, quantized CoreML"),
    ]
}

/// Gemini models available on the user's Vertex project.
enum ModelCatalog {
    static let known = [
        "gemini-3.5-flash-lite",
        "gemini-3.5-flash",
        "gemini-3.6-flash",
        "gemini-3.1-flash-lite",
        "gemini-3.1-pro-preview",
    ]
}

/// UserDefaults-backed settings, readable from any thread.
struct AppSettings {
    static var current: AppSettings { AppSettings() }

    private let defaults = UserDefaults.standard

    var mode: DictationMode {
        DictationMode(rawValue: defaults.string(forKey: "mode") ?? "") ?? .parakeetGemini
    }

    var gcpProject: String {
        defaults.string(forKey: "gcpProject") ?? ""
    }

    var gcpLocation: String {
        defaults.string(forKey: "gcpLocation") ?? "global"
    }

    var model: String {
        defaults.string(forKey: "geminiModel") ?? "gemini-3.5-flash-lite"
    }

    /// Which local speech-to-text model to use (id from SttCatalog).
    var sttModel: String {
        defaults.string(forKey: "sttModel") ?? "parakeet-v2"
    }

    /// Fall back to inserting the raw Parakeet transcript when Gemini fails.
    var fallbackToRaw: Bool {
        defaults.object(forKey: "fallbackToRaw") as? Bool ?? true
    }

    // MARK: Hotkey bindings

    var holdBinding: HotkeyBinding { binding(defaultsKey: "holdBinding", fallback: .defaultHold) }
    var toggleBinding: HotkeyBinding { binding(defaultsKey: "toggleBinding", fallback: .defaultToggle) }
    var cancelBinding: HotkeyBinding { binding(defaultsKey: "cancelBinding", fallback: .defaultCancel) }

    func binding(defaultsKey key: String, fallback: HotkeyBinding) -> HotkeyBinding {
        guard let data = defaults.data(forKey: key),
              let decoded = try? JSONDecoder().decode(HotkeyBinding.self, from: data) else {
            return fallback
        }
        return decoded
    }

    static func setBinding(_ binding: HotkeyBinding, forKey key: String) {
        UserDefaults.standard.set(try? JSONEncoder().encode(binding), forKey: key)
    }

    static func resetBindings() {
        for key in ["holdBinding", "toggleBinding", "cancelBinding"] {
            UserDefaults.standard.removeObject(forKey: key)
        }
    }
}
