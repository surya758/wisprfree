import AppKit
import SwiftUI

/// The app's window (settings + dictionary + history). Menu-bar apps have no
/// dock presence, so this is shown from the status menu and when the user
/// "re-opens" the app from Spotlight/Raycast/Finder.
///
/// Styled like macOS System Settings: full-height sidebar with the traffic
/// lights floating over it, no window title, no title-bar separator — the
/// pane title lives in the detail toolbar.
@MainActor
final class MainWindowController {
    static let shared = MainWindowController()
    private var window: NSWindow?

    func show() {
        if window == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 860, height: 620),
                styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )
            window.title = "WisprFree"
            window.titleVisibility = .hidden
            window.titlebarAppearsTransparent = true
            window.titlebarSeparatorStyle = .none
            window.toolbarStyle = .unified
            window.isReleasedWhenClosed = false
            window.contentMinSize = NSSize(width: 740, height: 520)
            window.contentViewController = NSHostingController(
                rootView: SettingsView().environmentObject(AppState.shared)
            )
            window.setContentSize(NSSize(width: 860, height: 620))
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
