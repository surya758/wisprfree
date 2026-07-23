import SwiftUI

struct HistoryView: View {
    @ObservedObject private var store = HistoryStore.shared

    var body: some View {
        List {
            // Hero lives inside the list so it scrolls away like other panes.
            Section {
                PaneHero(pane: .history)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
            }

            if store.items.isEmpty {
                Section {
                    Text("No dictations yet. Hold your dictation key and speak.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 24)
                        .listRowBackground(Color.clear)
                }
            } else {
                Section {
                    ForEach(store.items) { item in
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
                }
                Section {
                    Button("Clear History", role: .destructive) { store.clear() }
                }
            }
        }
        .listStyle(.inset)
        .scrollContentBackground(.hidden)
    }
}
