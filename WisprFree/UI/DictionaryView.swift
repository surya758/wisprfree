import SwiftUI

struct DictionaryView: View {
    @ObservedObject private var store = DictionaryStore.shared
    @State private var selection: Set<UUID> = []

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            PaneHero(pane: .dictionary)
            Text("Names and terms Gemini should always spell correctly (e.g. pinyin character names).")
                .font(.caption)
                .foregroundStyle(.secondary)

            Table(store.entries, selection: $selection) {
                TableColumn("Correct spelling") { entry in
                    TextField("Name or term", text: binding(for: entry.id, keyPath: \.term))
                }
                TableColumn("Often misheard as (optional)") { entry in
                    TextField("Common mishearings, comma-separated", text: binding(for: entry.id, keyPath: \.hint))
                }
            }

            HStack {
                Button {
                    store.entries.append(DictionaryEntry(term: ""))
                } label: {
                    Image(systemName: "plus")
                }
                Button {
                    store.entries.removeAll { selection.contains($0.id) }
                    selection.removeAll()
                } label: {
                    Image(systemName: "minus")
                }
                .disabled(selection.isEmpty)
                Spacer()
                Text("\(store.entries.count) terms")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
    }

    private func binding(for id: UUID, keyPath: WritableKeyPath<DictionaryEntry, String>) -> Binding<String> {
        Binding(
            get: {
                store.entries.first(where: { $0.id == id })?[keyPath: keyPath] ?? ""
            },
            set: { newValue in
                if let index = store.entries.firstIndex(where: { $0.id == id }) {
                    store.entries[index][keyPath: keyPath] = newValue
                }
            }
        )
    }
}
