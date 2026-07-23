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
            // Empty toolbar with unified style: makes the title-bar region
            // taller so the traffic lights sit lower — inside the floating
            // sidebar panel's top-left, like System Settings.
            let toolbar = NSToolbar()
            toolbar.showsBaselineSeparator = false
            window.toolbar = toolbar
            window.toolbarStyle = .unified
            window.backgroundColor = NSColor(red: 32 / 255, green: 34 / 255, blue: 45 / 255, alpha: 1)
            window.isReleasedWhenClosed = false
            window.contentMinSize = NSSize(width: 740, height: 520)
            window.contentViewController = NSHostingController(
                rootView: SettingsView().environmentObject(AppState.shared)
            )
            window.setContentSize(NSSize(width: 860, height: 620))
            window.center()
            self.window = window

            // AppKit resets the standard-button frames on every layout pass,
            // so re-apply our inset position whenever the window changes.
            NotificationCenter.default.addObserver(
                forName: NSWindow.didResizeNotification, object: window, queue: .main
            ) { [weak self] _ in
                Task { @MainActor in self?.positionTrafficLights() }
            }
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
        positionTrafficLights()
        // SwiftUI focuses the first text field and selects its contents when
        // the window opens (so the model/project fields appear "selected");
        // clear focus so nothing is highlighted until the user clicks.
        DispatchQueue.main.async { [weak self] in
            self?.window?.makeFirstResponder(nil)
            self?.positionTrafficLights()
        }
    }

    /// Moves the traffic lights deeper into the floating sidebar panel
    /// (default AppKit position hugs the window corner).
    private func positionTrafficLights() {
        guard let window else { return }
        let types: [NSWindow.ButtonType] = [.closeButton, .miniaturizeButton, .zoomButton]
        guard let container = window.standardWindowButton(.closeButton)?.superview else { return }
        let leftInset: CGFloat = 34   // from window left edge
        let topInset: CGFloat = 32    // from window top edge
        for (index, type) in types.enumerated() {
            guard let button = window.standardWindowButton(type) else { continue }
            let size = button.frame.size
            button.setFrameOrigin(NSPoint(
                x: leftInset + CGFloat(index) * (size.width + 6),
                y: container.frame.height - topInset - size.height
            ))
        }
    }
}
