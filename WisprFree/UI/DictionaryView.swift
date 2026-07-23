import SwiftUI

struct DictionaryView: View {
    @ObservedObject private var store = DictionaryStore.shared
    @State private var hoveredID: UUID?

    var body: some View {
        Form {
            PaneHeroSection(pane: .dictionary)

            Section {
                if store.entries.isEmpty {
                    Text("No terms yet. Add names the AI should always spell correctly.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 4)
                }
                ForEach($store.entries) { $entry in
                    HStack(spacing: 10) {
                        VStack(alignment: .leading, spacing: 2) {
                            TextField("Name or term", text: $entry.term)
                                .textFieldStyle(.plain)
                            TextField("Common mishearings, comma-separated (optional)", text: $entry.hint)
                                .textFieldStyle(.plain)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer(minLength: 0)
                        Button {
                            store.entries.removeAll { $0.id == entry.id }
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                        .help("Delete")
                        .opacity(hoveredID == entry.id ? 1 : 0)
                        .allowsHitTesting(hoveredID == entry.id)
                    }
                    .contentShape(Rectangle())
                    .onHover { inside in
                        if inside { hoveredID = entry.id }
                        else if hoveredID == entry.id { hoveredID = nil }
                    }
                }
                .animation(.easeInOut(duration: 0.12), value: hoveredID)

                Button {
                    store.entries.append(DictionaryEntry(term: ""))
                } label: {
                    Label("Add Term", systemImage: "plus")
                }
            } header: {
                Text("Terms")
            } footer: {
                Text("Hover a row and click ✕ to remove it. Applied only in Writing mode.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
    }
}
