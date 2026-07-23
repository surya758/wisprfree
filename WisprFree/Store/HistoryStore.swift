import Foundation

struct HistoryItem: Codable, Identifiable {
    var id = UUID()
    var date: Date
    var text: String
    /// Raw Parakeet transcript before cleanup (empty in direct mode).
    var raw: String
    var mode: String
}

/// Last 50 dictations, persisted as JSON in Application Support.
@MainActor
final class HistoryStore: ObservableObject {
    static let shared = HistoryStore()

    @Published private(set) var items: [HistoryItem] = []

    private static var fileURL: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("WisprFree", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("history.json")
    }

    private init() {
        if let data = try? Data(contentsOf: Self.fileURL),
           let saved = try? JSONDecoder().decode([HistoryItem].self, from: data) {
            items = saved
        }
    }

    func add(text: String, raw: String, mode: DictationMode) {
        let text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let raw = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        items.insert(HistoryItem(date: Date(), text: text, raw: raw, mode: mode.label), at: 0)
        if items.count > 50 { items.removeLast(items.count - 50) }
        if let data = try? JSONEncoder().encode(items) {
            try? data.write(to: Self.fileURL, options: .atomic)
        }
    }

    func clear() {
        items.removeAll()
        try? FileManager.default.removeItem(at: Self.fileURL)
    }
}
