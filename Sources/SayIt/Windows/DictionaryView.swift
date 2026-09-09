import SwiftUI

/// Custom vocabulary and text replacements, both live in the dictation
/// pipeline: replacements are applied deterministically ("brb" → "be right
/// back"), plain words become spelling preferences for smart formatting.
struct DictionaryView: View {
    @State private var newSpoken = ""
    @State private var newReplacement = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Dictionary")
                    .font(Theme.display(24))
                    .tracking(-0.6)
                    .foregroundStyle(Theme.text)
                Text("Teach SayIt your names, jargon, and shortcuts.")
                    .font(Theme.body(12.5))
                    .foregroundStyle(Theme.textDim)
            }
            .padding(.top, 8)

            addForm

            if Store.shared.entries.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(Store.shared.entries) { entry in
                            EntryRow(entry: entry)
                                .transition(.opacity.combined(with: .move(edge: .top)))
                        }
                    }
                    .animation(Theme.spring, value: Store.shared.entries)
                }
            }
        }
        .padding(22)
    }

    private var addForm: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    SectionHeader(title: "When you say")
                    TextField("e.g.  Ishan   or   brb", text: $newSpoken)
                        .textFieldStyle(.plain)
                        .font(Theme.body(12.5))
                        .foregroundStyle(Theme.text)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .well()
                }
                VStack(alignment: .leading, spacing: 4) {
                    SectionHeader(title: "SayIt types (optional)")
                    TextField("e.g.  be right back", text: $newReplacement)
                        .textFieldStyle(.plain)
                        .font(Theme.body(12.5))
                        .foregroundStyle(Theme.text)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .well()
                        .onSubmit(add)
                }
                Button("Add", action: add)
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(newSpoken.trimmingCharacters(in: .whitespaces).isEmpty)
                    .opacity(newSpoken.trimmingCharacters(in: .whitespaces).isEmpty ? 0.35 : 1)
                    .padding(.top, 16)
            }
            Text("Leave the second field empty to add a spelling preference — a name or term SayIt should get right.")
                .font(.system(size: 10.5))
                .foregroundStyle(Theme.textFaint)
        }
        .card(padding: 14)
    }

    private func add() {
        let spoken = newSpoken.trimmingCharacters(in: .whitespaces)
        guard !spoken.isEmpty else { return }
        withAnimation(Theme.spring) {
            Store.shared.addEntry(spoken: spoken, replacement: newReplacement)
        }
        newSpoken = ""
        newReplacement = ""
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "character.book.closed.fill")
                .font(.system(size: 26))
                .foregroundStyle(Theme.textFaint)
            Text("No entries yet. Add a name SayIt should spell right,\nor a shortcut that expands as you speak.")
                .font(Theme.body(12.5))
                .foregroundStyle(Theme.textFaint)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}

private struct EntryRow: View {
    let entry: DictionaryEntry
    @State private var hovering = false

    var body: some View {
        HStack(spacing: 10) {
            Text(entry.spoken)
                .font(Theme.body(12.5))
                .foregroundStyle(Theme.text)
            if entry.isVocabulary {
                Text("spelling")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Theme.accent)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Theme.citron.opacity(0.14)))
            } else {
                Image(systemName: "arrow.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Theme.textFaint)
                Text(entry.replacement)
                    .font(Theme.body(12.5))
                    .foregroundStyle(Theme.textDim)
            }
            Spacer()
            if hovering {
                Button {
                    withAnimation(Theme.spring) { Store.shared.deleteEntry(entry) }
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(RowActionButtonStyle(destructive: true))
                .transition(.opacity)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous)
                .fill(hovering ? Theme.fillFaint : Theme.raised)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous)
                .strokeBorder(Theme.hairline, lineWidth: 1)
        )
        .onHover { hovering = $0 }
        .animation(Theme.springFast, value: hovering)
    }
}
