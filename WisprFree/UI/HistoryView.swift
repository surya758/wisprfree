import SwiftUI

struct HistoryView: View {
    @ObservedObject private var store = HistoryStore.shared

    var body: some View {
        VStack(alignment: .leading) {
            PaneHero(pane: .history)
                .padding([.horizontal, .top])
            if store.items.isEmpty {
                ContentUnavailableView(
                    "No dictations yet",
                    systemImage: "mic",
                    description: Text("Hold your dictation key and speak.")
                )
            } else {
                List(store.items) { item in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(item.date, style: .time)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(item.mode)
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                            Spacer()
                            Button("Copy") {
                                NSPasteboard.general.clearContents()
                                NSPasteboard.general.setString(item.text, forType: .string)
                            }
                            .buttonStyle(.borderless)
                        }
                        Text(item.text)
                            .textSelection(.enabled)
                            .lineLimit(4)
                    }
                    .padding(.vertical, 2)
                }

                Button("Clear History") { store.clear() }
                    .padding([.horizontal, .bottom])
            }
        }
    }
}
