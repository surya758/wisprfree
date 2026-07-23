import SwiftUI
import Sparkle

/// Wraps Sparkle's updater so SwiftUI views can trigger an update check and
/// reflect whether one is currently allowed.
@MainActor
final class Updater: ObservableObject {
    static let shared = Updater()

    private let controller: SPUStandardUpdaterController
    @Published var canCheck = true

    private init() {
        // startingUpdater: true begins the scheduled background checks using
        // SUFeedURL / SUPublicEDKey from Info.plist.
        controller = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
        controller.updater.publisher(for: \.canCheckForUpdates)
            .receive(on: RunLoop.main)
            .assign(to: &$canCheck)
    }

    func checkForUpdates() {
        controller.updater.checkForUpdates()
    }

    var automaticallyChecks: Bool {
        get { controller.updater.automaticallyChecksForUpdates }
        set { controller.updater.automaticallyChecksForUpdates = newValue }
    }

    /// Human-readable last-check time, or nil if never checked.
    var lastCheckDescription: String? {
        guard let date = controller.updater.lastUpdateCheckDate else { return nil }
        if Date().timeIntervalSince(date) < 60 { return "just now" }
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .full
        return f.localizedString(for: date, relativeTo: Date())
    }
}

/// "Check for Updates…" menu command, disabled while a check is mid-flight.
struct CheckForUpdatesButton: View {
    @ObservedObject private var updater = Updater.shared

    var body: some View {
        Button("Check for Updates…") {
            updater.checkForUpdates()
        }
        .disabled(!updater.canCheck)
    }
}
