import Foundation

struct DictionaryEntry: Codable, Identifiable, Equatable {
    var id = UUID()
    /// The correct spelling of the name or term.
    var term: String
    /// Optional comma-separated common mishearings.
    var hint: String = ""
}

/// Glossary of names/terms, persisted as JSON in Application Support.
@MainActor
final class DictionaryStore: ObservableObject {
    static let shared = DictionaryStore()

    @Published var entries: [DictionaryEntry] = [] {
        didSet { save() }
    }

    private static var fileURL: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("WisprFree", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("dictionary.json")
    }

    private init() {
        if let data = try? Data(contentsOf: Self.fileURL),
           let saved = try? JSONDecoder().decode([DictionaryEntry].self, from: data) {
            entries = saved
        }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(entries) {
            try? data.write(to: Self.fileURL, options: .atomic)
        }
    }
}
