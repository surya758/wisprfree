import AppKit
import ApplicationServices

/// Puts cleaned text into the frontmost app. Three strategies (Settings):
/// - paste: clipboard + ⌘V, then restore the clipboard (fast, but touches it)
/// - type: synthesize the characters directly (no clipboard; works in
///   terminals and apps that ignore ⌘V)
/// - copyOnly: just leave it on the clipboard
/// All except copyOnly require the Accessibility permission.
enum TextInserter {
    static func insert(_ text: String) throws {
        switch AppSettings.current.insertionMethod {
        case .copyOnly:
            copyToClipboard(text)
        case .type:
            guard ensureAccessibility() else {
                copyToClipboard(text)
                throw WisprError.accessibilityDenied
            }
            typeText(text)
        case .paste:
            guard ensureAccessibility() else {
                copyToClipboard(text)
                throw WisprError.accessibilityDenied
            }
            paste(text)
        }
    }

    private static func copyToClipboard(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    // MARK: - Paste (⌘V)

    private static func paste(_ text: String) {
        let pasteboard = NSPasteboard.general
        let previous = pasteboard.string(forType: .string)
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        pressCommandV()

        // Restore the user's clipboard after the paste has been consumed.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            if pasteboard.string(forType: .string) == text, let previous {
                pasteboard.clearContents()
                pasteboard.setString(previous, forType: .string)
            }
        }
    }

    private static func pressCommandV() {
        let source = CGEventSource(stateID: .combinedSessionState)
        let keyVDown = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: true)
        let keyVUp = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: false)
        keyVDown?.flags = .maskCommand
        keyVUp?.flags = .maskCommand
        keyVDown?.post(tap: .cghidEventTap)
        keyVUp?.post(tap: .cghidEventTap)
    }

    // MARK: - Type characters (Unicode, no clipboard)

    private static func typeText(_ text: String) {
        let source = CGEventSource(stateID: .combinedSessionState)
        for character in text {
            if character == "\n" || character == "\r" {
                // Post an actual Return key so editors treat it as a newline.
                postKey(36, source: source)
                continue
            }
            let utf16 = Array(String(character).utf16)
            postUnicode(utf16, source: source)
        }
    }

    private static func postUnicode(_ utf16: [UniChar], source: CGEventSource?) {
        for down in [true, false] {
            guard let event = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: down) else { continue }
            event.keyboardSetUnicodeString(stringLength: utf16.count, unicodeString: utf16)
            event.post(tap: .cghidEventTap)
        }
    }

    private static func postKey(_ keyCode: CGKeyCode, source: CGEventSource?) {
        CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true)?.post(tap: .cghidEventTap)
        CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false)?.post(tap: .cghidEventTap)
    }

    // MARK: - Accessibility

    /// Prompts the user (once, via the system dialog) if not yet trusted.
    @discardableResult
    static func ensureAccessibility() -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    /// Current trust state, without prompting.
    static var isAccessibilityTrusted: Bool { AXIsProcessTrusted() }
}
