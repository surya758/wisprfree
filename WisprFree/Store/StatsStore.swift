import Foundation

struct DayStat: Codable {
    var words: Int = 0
    var dictations: Int = 0
    var audioSeconds: Double = 0
}

/// Per-day dictation statistics, persisted as JSON in Application Support.
@MainActor
final class StatsStore: ObservableObject {
    static let shared = StatsStore()

    /// Keyed by "yyyy-MM-dd" (local time).
    @Published private(set) var days: [String: DayStat] = [:]

    private static var fileURL: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("WisprFree", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("stats.json")
    }

    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private init() {
        if let data = try? Data(contentsOf: Self.fileURL),
           let saved = try? JSONDecoder().decode([String: DayStat].self, from: data) {
            days = saved
        }
    }

    func record(text: String, audioSeconds: Double) {
        let words = text.split { $0.isWhitespace || $0.isNewline }.count
        let key = Self.dayFormatter.string(from: Date())
        var day = days[key] ?? DayStat()
        day.words += words
        day.dictations += 1
        day.audioSeconds += audioSeconds
        days[key] = day
        if let data = try? JSONEncoder().encode(days) {
            try? data.write(to: Self.fileURL, options: .atomic)
        }
    }

    // MARK: Aggregates

    var today: DayStat {
        days[Self.dayFormatter.string(from: Date())] ?? DayStat()
    }

    /// Last 7 days including today.
    var thisWeek: DayStat {
        aggregate(daysBack: 7)
    }

    var allTime: DayStat {
        days.values.reduce(into: DayStat()) { partial, day in
            partial.words += day.words
            partial.dictations += day.dictations
            partial.audioSeconds += day.audioSeconds
        }
    }

    /// Consecutive days (ending today or yesterday) with at least one dictation.
    var streakDays: Int {
        var streak = 0
        var date = Date()
        // A streak survives if today has no dictation yet but yesterday did.
        if days[Self.dayFormatter.string(from: date)] == nil {
            date = Calendar.current.date(byAdding: .day, value: -1, to: date)!
        }
        while days[Self.dayFormatter.string(from: date)] != nil {
            streak += 1
            date = Calendar.current.date(byAdding: .day, value: -1, to: date)!
        }
        return streak
    }

    /// Rough minutes saved vs. typing at 40 words/minute, minus speaking time.
    var minutesSavedAllTime: Double {
        let stat = allTime
        return max(0, Double(stat.words) / 40.0 - stat.audioSeconds / 60.0)
    }

    private func aggregate(daysBack: Int) -> DayStat {
        var result = DayStat()
        for offset in 0..<daysBack {
            let date = Calendar.current.date(byAdding: .day, value: -offset, to: Date())!
            if let day = days[Self.dayFormatter.string(from: date)] {
                result.words += day.words
                result.dictations += day.dictations
                result.audioSeconds += day.audioSeconds
            }
        }
        return result
    }
}
