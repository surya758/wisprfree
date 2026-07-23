import SwiftUI

struct DictionaryView: View {
    @ObservedObject private var store = DictionaryStore.shared
    @State private var selection: Set<UUID> = []

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Names and terms the AI should always spell correctly. Applied only in Writing mode.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 2)

            // Native-style inset table with an attached add/remove footer bar.
            VStack(spacing: 0) {
                Table(store.entries, selection: $selection) {
                    TableColumn("Term") { entry in
                        TextField("Name or term", text: binding(for: entry.id, keyPath: \.term))
                            .textFieldStyle(.plain)
                    }
                    TableColumn("Often misheard as (optional)") { entry in
                        TextField("Comma-separated", text: binding(for: entry.id, keyPath: \.hint))
                            .textFieldStyle(.plain)
                            .foregroundStyle(.secondary)
                    }
                }
                .tableStyle(.inset(alternatesRowBackgrounds: true))
                .scrollContentBackground(.hidden)

                Divider()

                HStack(spacing: 0) {
                    footerButton("plus") {
                        let entry = DictionaryEntry(term: "")
                        store.entries.append(entry)
                        selection = [entry.id]
                    }
                    Divider().frame(height: 14)
                    footerButton("minus") {
                        store.entries.removeAll { selection.contains($0.id) }
                        selection.removeAll()
                    }
                    .disabled(selection.isEmpty)
                    Spacer()
                }
                .frame(height: 26)
                .background(.white.opacity(0.03))
            }
            .background(RoundedRectangle(cornerRadius: 8).fill(.black.opacity(0.15)))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(.white.opacity(0.1), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .padding(20)
    }

    private func footerButton(_ symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 11, weight: .medium))
                .frame(width: 26, height: 26)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(.secondary)
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
