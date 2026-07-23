import SwiftUI

/// Dictation statistics: words today, streak, totals, time saved.
struct InsightsView: View {
    @ObservedObject private var stats = StatsStore.shared

    var body: some View {
        Form {
            Section("Today") {
                HStack(spacing: 10) {
                    StatTile(value: formatted(stats.today.words), label: "words")
                    StatTile(value: "\(stats.today.dictations)", label: "dictations")
                    StatTile(value: minutes(stats.today.audioSeconds), label: "spoken")
                }
            }

            Section("Last 7 days") {
                HStack(spacing: 10) {
                    StatTile(value: formatted(stats.thisWeek.words), label: "words")
                    StatTile(value: "\(stats.thisWeek.dictations)", label: "dictations")
                    StatTile(value: "\(stats.streakDays) day\(stats.streakDays == 1 ? "" : "s")", label: "streak")
                }
            }

            Section("All time") {
                LabeledContent("Words dictated", value: formatted(stats.allTime.words))
                LabeledContent("Dictations", value: formatted(stats.allTime.dictations))
                LabeledContent("Time spoken", value: minutes(stats.allTime.audioSeconds))
                LabeledContent("Average words per dictation", value: stats.allTime.dictations > 0
                    ? "\(stats.allTime.words / stats.allTime.dictations)" : "—")
                LabeledContent {
                    Text(minutes(stats.minutesSavedAllTime * 60))
                } label: {
                    Text("Estimated typing time saved")
                    Text("vs. typing at 40 words/minute")
                }
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
    }

    private func formatted(_ number: Int) -> String {
        number.formatted(.number.grouping(.automatic))
    }

    private func minutes(_ seconds: Double) -> String {
        if seconds < 60 { return "\(Int(seconds))s" }
        let totalMinutes = Int(seconds / 60)
        if totalMinutes < 60 { return "\(totalMinutes) min" }
        return String(format: "%dh %02dm", totalMinutes / 60, totalMinutes % 60)
    }
}

/// Hero-number tile: value in primary ink, label in secondary — no
/// decorative color carries meaning.
struct StatTile: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 22, weight: .semibold, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 8).fill(.quaternary.opacity(0.5)))
    }
}
