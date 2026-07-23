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

    var body: some View {
        Group {
            if store.items.isEmpty {
                ContentUnavailableView(
                    "No dictations yet",
                    systemImage: "mic",
                    description: Text("Hold your dictation key and speak.")
                )
            } else {
                VStack(spacing: 0) {
                    List {
                        ForEach(store.items) { item in
                            HistoryRow(item: item)
                                .listRowSeparator(.hidden)
                        }
                    }
                    .listStyle(.inset)
                    .scrollContentBackground(.hidden)

                    // Fixed footer — stays put while the list scrolls.
                    Divider()
                    HStack {
                        Spacer()
                        Button("Clear History", role: .destructive) { store.clear() }
                    }
                    .padding(10)
                }
            }
        }
    }
}

/// One dictation. Its own state so hover is independent per row; a short
/// delay before the highlight appears avoids flicker when sweeping the list.
private struct HistoryRow: View {
    let item: HistoryItem
    @State private var hovered = false
    @State private var copied = false
    @State private var hoverWork: DispatchWorkItem?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Text(item.date, style: .time)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(item.mode)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                Spacer()
                // Fixed-size slot so the hint toggling never shifts layout.
                ZStack(alignment: .trailing) {
                    Label("Click to copy", systemImage: "doc.on.doc").opacity(0)
                    if copied {
                        Label("Copied", systemImage: "checkmark")
                            .foregroundStyle(.green)
                    } else if hovered {
                        Label("Click to copy", systemImage: "doc.on.doc")
                            .foregroundStyle(.secondary)
                    }
                }
                .font(.caption)
            }
            Text(item.text.trimmingCharacters(in: .whitespacesAndNewlines))
                .lineLimit(4)
        }
        .padding(.vertical, 5)
        .padding(.horizontal, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(hovered ? Color.white.opacity(0.06) : .clear)
        )
        .contentShape(Rectangle())
        .linkCursor()
        .onHover { inside in
            hoverWork?.cancel()
            if inside {
                let work = DispatchWorkItem {
                    withAnimation(.easeInOut(duration: 0.12)) { hovered = true }
                }
                hoverWork = work
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15, execute: work)
            } else {
                withAnimation(.easeInOut(duration: 0.12)) { hovered = false }
            }
        }
        .onTapGesture {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(
                item.text.trimmingCharacters(in: .whitespacesAndNewlines), forType: .string)
            withAnimation { copied = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                withAnimation { copied = false }
            }
        }
    }
}
