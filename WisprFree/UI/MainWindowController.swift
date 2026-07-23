import AppKit
import SwiftUI

/// The app's window (settings + dictionary + history). Menu-bar apps have no
/// dock presence, so this is shown from the status menu and when the user
/// "re-opens" the app from Spotlight/Raycast/Finder.
@MainActor
final class MainWindowController {
    static let shared = MainWindowController()
    private var window: NSWindow?

    func show() {
        if window == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 700, height: 480),
                styleMask: [.titled, .closable, .miniaturizable, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )
            window.titlebarAppearsTransparent = true
            window.title = "WisprFree"
            window.isReleasedWhenClosed = false
            window.contentView = NSHostingView(
                rootView: SettingsView().environmentObject(AppState.shared)
            )
            window.center()
            self.window = window
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
        // SwiftUI focuses the first text field and selects its contents when
        // the window opens (so the model/project fields appear "selected");
        // clear focus so nothing is highlighted until the user clicks.
        DispatchQueue.main.async { [weak self] in
            self?.window?.makeFirstResponder(nil)
        }
    }
}
