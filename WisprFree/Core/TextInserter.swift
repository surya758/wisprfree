import AppKit
import ApplicationServices

/// Inserts text into the frontmost app by putting it on the pasteboard and
/// synthesizing ⌘V, then restoring the previous pasteboard contents.
/// Requires the Accessibility permission.
enum TextInserter {
    static func insert(_ text: String) throws {
        guard ensureAccessibility() else {
            // Still make the text available even though we can't type it.
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(text, forType: .string)
            throw WisprError.accessibilityDenied
        }

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

    /// Prompts the user (once, via the system dialog) if not yet trusted.
    @discardableResult
    static func ensureAccessibility() -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    /// Current trust state, without prompting.
    static var isAccessibilityTrusted: Bool { AXIsProcessTrusted() }

    private static func pressCommandV() {
        let source = CGEventSource(stateID: .combinedSessionState)
        let keyVDown = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: true)
        let keyVUp = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: false)
        keyVDown?.flags = .maskCommand
        keyVUp?.flags = .maskCommand
        keyVDown?.post(tap: .cghidEventTap)
        keyVUp?.post(tap: .cghidEventTap)
    }
}
