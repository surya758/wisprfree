import SwiftUI

@main
struct WisprFreeApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var appState = AppState.shared

    var body: some Scene {
        MenuBarExtra {
            MenuContent()
                .environmentObject(appState)
        } label: {
            Image(systemName: appState.phase.symbolName)
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        if !UserDefaults.standard.bool(forKey: "onboardingDone") {
            // First run: guided setup.
            OnboardingWindowController.shared.show()
        } else if !TextInserter.isAccessibilityTrusted {
            // Missing permission: surface the window so the user isn't left
            // staring at nothing but a menu-bar icon.
            MainWindowController.shared.show()
        }
    }

    /// Launching the app again (Spotlight, Raycast, Finder) lands here —
    /// show the window instead of silently doing nothing.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        MainWindowController.shared.show()
        return true
    }
}

/// Global app state driving the menu-bar icon, overlay, and windows.
@MainActor
final class AppState: ObservableObject {
    static let shared = AppState()

    enum Phase {
        case idle
        case loadingModel
        case recording
        case processing
        case error

        var symbolName: String {
            switch self {
            case .idle: return "mic"
            case .loadingModel: return "arrow.down.circle"
            case .recording: return "mic.fill"
            case .processing: return "ellipsis.circle"
            case .error: return "mic.slash"
            }
        }

        var label: String {
            switch self {
            case .idle: return "Ready to dictate"
            case .loadingModel: return "Downloading speech model…"
            case .recording: return "Recording…"
            case .processing: return "Transcribing…"
            case .error: return "Error — see below"
            }
        }
    }

    @Published var phase: Phase = .idle
    @Published var audioLevel: Float = 0
    /// Fraction [0,1] of a model download in flight; nil when none.
    @Published var downloadProgress: Double?
    @Published var lastError: String?
    @Published var lastResult: String?

    let pipeline = DictationPipeline()
    private var hotkeys: HotkeyManager?
    private var overlay: RecordingOverlayController?

    private init() {
        // Ask for Accessibility up front: the hotkey event tap (and pasting
        // into other apps) can't work without it, so waiting until first
        // insert would leave the hotkeys silently dead.
        TextInserter.ensureAccessibility()
        _ = Updater.shared  // start Sparkle's scheduled update checks
        hotkeys = HotkeyManager(pipeline: pipeline)
        overlay = RecordingOverlayController(appState: self)
        // Warm up the local speech model in the background so the first
        // dictation doesn't pay the load cost.
        Task { await pipeline.warmUp() }
    }

    /// Cancel from UI (overlay ✕): discard audio and reset key tracking.
    func cancelDictation() {
        pipeline.cancelRecording()
        hotkeys?.resetStyle()
    }
}

struct MenuContent: View {
    @EnvironmentObject var appState: AppState
    @AppStorage("dictationProfile") private var profile = DictationProfile.casual.rawValue

    var body: some View {
        Text(appState.phase.label)
        Picker("Mode", selection: $profile) {
            ForEach(DictationProfile.allCases) { profile in
                Text(profile.label).tag(profile.rawValue)
            }
        }
        .pickerStyle(.inline)
        if let error = appState.lastError, appState.phase == .error {
            Text(error).font(.caption)
        }
        if let result = appState.lastResult {
            Button("Copy Last Dictation") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(result, forType: .string)
            }
        }
        Divider()
        Button("Settings…") {
            MainWindowController.shared.show()
        }
        .keyboardShortcut(",")
        CheckForUpdatesButton()
        Divider()
        Button("Quit WisprFree") { NSApp.terminate(nil) }
            .keyboardShortcut("q")
    }
}
