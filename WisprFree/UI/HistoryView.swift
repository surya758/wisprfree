import SwiftUI

extension View {
    /// Pointing-hand cursor over clickable content. Re-applies on every move
    /// so AppKit's tracking areas can't reset it back to the arrow.
    func linkCursor() -> some View {
        onContinuousHover { phase in
            switch phase {
            case .active:
                if NSCursor.current != NSCursor.pointingHand {
                    NSCursor.pointingHand.set()
                }
            case .ended:
                NSCursor.arrow.set()
            }
        }
    }
}

struct HistoryView: View {
    @ObservedObject private var store = HistoryStore.shared

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEEE, MMMM d"
        return f
    }()

    /// Items grouped by calendar day, newest day first.
    private var groups: [(label: String, items: [HistoryItem])] {
        let cal = Calendar.current
        let byDay = Dictionary(grouping: store.items) { cal.startOfDay(for: $0.date) }
        return byDay.keys.sorted(by: >).map { day in
            let label: String
            if cal.isDateInToday(day) { label = "Today" }
            else if cal.isDateInYesterday(day) { label = "Yesterday" }
            else { label = Self.dayFormatter.string(from: day) }
            return (label, byDay[day] ?? [])
        }
    }

    var body: some View {
        if store.items.isEmpty {
            ContentUnavailableView(
                "No dictations yet",
                systemImage: "waveform",
                description: Text("Hold your dictation key and speak — your dictations show up here.")
            )
        } else {
            VStack(spacing: 0) {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 22, pinnedViews: [.sectionHeaders]) {
                        ForEach(groups, id: \.label) { group in
                            Section {
                                VStack(spacing: 8) {
                                    ForEach(group.items) { item in
                                        HistoryCard(item: item)
                                    }
                                }
                            } header: {
                                HStack {
                                    Text(group.label)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(.secondary)
                                    Spacer()
                                    Text("\(group.items.count)")
                                        .font(.caption)
                                        .foregroundStyle(.tertiary)
                                }
                                .padding(.vertical, 4)
                                .background(SettingsColors.app)
                            }
                        }
                    }
                    .padding(20)
                }

                Divider()
                HStack {
                    Text("\(store.items.count) dictation\(store.items.count == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Clear History", role: .destructive) { store.clear() }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
            }
        }
    }
}

/// A single dictation, as a card: the text, then a metadata footer with time,
/// word count, mode dot, and a copy affordance. Click anywhere to copy.
private struct HistoryCard: View {
    let item: HistoryItem
    @State private var hovered = false
    @State private var copied = false

    private var text: String {
        item.text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var wordCount: Int {
        text.split { $0.isWhitespace || $0.isNewline }.count
    }

    // Color-code the pipeline mode so entries are scannable at a glance.
    private var modeColor: Color {
        if item.mode.contains("directly") { return .orange }
        if item.mode.contains("offline") || item.mode.contains("raw") { return .gray }
        return Color(red: 0.35, green: 0.5, blue: 0.9)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(text)
                .font(.callout)
                .lineLimit(6)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 8) {
                Circle().fill(modeColor).frame(width: 6, height: 6)
                Text(item.date, style: .time)
                Text("·")
                Text("\(wordCount) word\(wordCount == 1 ? "" : "s")")
                Spacer()
                // Fixed slot so the label never shifts the footer.
                ZStack(alignment: .trailing) {
                    Label("Copied", systemImage: "checkmark").opacity(0)
                    if copied {
                        Label("Copied", systemImage: "checkmark")
                            .foregroundStyle(.green)
                    } else {
                        Label("Copy", systemImage: "doc.on.doc")
                            .opacity(hovered ? 1 : 0)
                    }
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(.white.opacity(hovered ? 0.07 : 0.03))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(.white.opacity(hovered ? 0.13 : 0.06), lineWidth: 1)
        )
        .contentShape(Rectangle())
        .linkCursor()
        .onHover { inside in
            withAnimation(.easeInOut(duration: 0.12)) { hovered = inside }
        }
        .onTapGesture {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(text, forType: .string)
            withAnimation { copied = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                withAnimation { copied = false }
            }
        }
    }
}
