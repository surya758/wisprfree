import SwiftUI

struct HistoryView: View {
    @ObservedObject private var store = HistoryStore.shared
    @State private var hoveredID: UUID?
    @State private var copiedID: UUID?

    var body: some View {
        Group {
            if store.items.isEmpty {
                ContentUnavailableView(
                    "No dictations yet",
                    systemImage: "mic",
                    description: Text("Hold your dictation key and speak.")
                )
            } else {
                List {
                    ForEach(store.items) { item in
                        row(for: item)
                    }
                    Section {
                        Button("Clear History", role: .destructive) { store.clear() }
                    }
                }
                .listStyle(.inset)
                .scrollContentBackground(.hidden)
            }
        }
    }

    private func row(for item: HistoryItem) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Text(item.date, style: .time)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(item.mode)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                Spacer()
                if copiedID == item.id {
                    Label("Copied", systemImage: "checkmark")
                        .font(.caption)
                        .foregroundStyle(.green)
                } else if hoveredID == item.id {
                    Label("Click to copy", systemImage: "doc.on.doc")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Text(item.text)
                .lineLimit(4)
        }
        .padding(.vertical, 5)
        .padding(.horizontal, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(hoveredID == item.id ? Color.white.opacity(0.06) : .clear)
        )
        .contentShape(Rectangle())
        .onHover { inside in
            if inside { hoveredID = item.id }
            else if hoveredID == item.id { hoveredID = nil }
        }
        .onTapGesture {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(item.text, forType: .string)
            copiedID = item.id
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                if copiedID == item.id { copiedID = nil }
            }
        }
        .listRowSeparator(.hidden)
    }
}
