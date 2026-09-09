import AppKit
import SwiftUI

/// Every dictation, searchable. Hover a row to copy or delete.
struct HistoryView: View {
    @State private var query = ""
    @State private var confirmClear = false

    private var filtered: [DictationRecord] {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return Store.shared.records }
        return Store.shared.records.filter {
            $0.text.localizedCaseInsensitiveContains(trimmed)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("History")
                    .font(Theme.display(24))
                    .tracking(-0.6)
                    .foregroundStyle(Theme.text)
                Text("\(Store.shared.records.count)")
                    .font(Theme.mono(13))
                    .foregroundStyle(Theme.textFaint)
                Spacer()
                if !Store.shared.records.isEmpty {
                    Button("Clear all") { confirmClear = true }
                        .buttonStyle(LinkButtonStyle())
                        .confirmationDialog("Delete all dictation history?", isPresented: $confirmClear) {
                            Button("Delete all", role: .destructive) {
                                withAnimation(Theme.spring) { Store.shared.clearRecords() }
                            }
                        }
                }
            }
            .padding(.top, 8)

            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textFaint)
                TextField("Search dictations", text: $query)
                    .textFieldStyle(.plain)
                    .font(Theme.body(12.5))
                    .foregroundStyle(Theme.text)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .well()

            if filtered.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(filtered) { record in
                            RecordRow(record: record)
                                .transition(.opacity.combined(with: .move(edge: .top)))
                        }
                    }
                    .animation(Theme.spring, value: filtered)
                }
            }
        }
        .padding(22)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            WaveMark(height: 28, color: Theme.textFaint)
            Text(query.isEmpty ? "Nothing here yet — hold fn and say something." : "No matches for “\(query)”.")
                .font(Theme.body(12.5))
                .foregroundStyle(Theme.textFaint)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}

private struct RecordRow: View {
    let record: DictationRecord
    @State private var hovering = false
    @State private var copied = false
    @State private var showRaw = false

    private var wasCleaned: Bool { record.raw != record.text }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(record.text)
                .font(Theme.body(12.5))
                .foregroundStyle(Theme.text)
                .lineLimit(showRaw ? nil : 2)
                .frame(maxWidth: .infinity, alignment: .leading)
            HStack(spacing: 10) {
                Text(record.date.formatted(.relative(presentation: .named)))
                Text("\(record.wordCount) words")
                if record.wpm > 0 {
                    Text("\(record.wpm) wpm")
                        .font(Theme.mono(10.5, weight: .medium))
                }
                if wasCleaned {
                    Button {
                        withAnimation(Theme.spring) { showRaw.toggle() }
                    } label: {
                        HStack(spacing: 3) {
                            Image(systemName: "sparkles")
                            Text("cleaned")
                            Image(systemName: showRaw ? "chevron.up" : "chevron.down")
                                .font(.system(size: 8, weight: .bold))
                        }
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Theme.accent)
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
            }
            .font(.system(size: 10.5))
            .foregroundStyle(Theme.textFaint)

            if showRaw && wasCleaned {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        SectionHeader(title: "What was heard")
                        Spacer()
                        Button {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(record.raw, forType: .string)
                        } label: {
                            Text("Copy raw")
                        }
                        .buttonStyle(LinkButtonStyle())
                    }
                    Text(record.raw)
                        .font(Theme.body(12))
                        .foregroundStyle(Theme.textDim)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(10)
                .well()
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous)
                .fill(hovering ? Theme.fillFaint : Theme.raised)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous)
                .strokeBorder(Theme.hairline, lineWidth: 1)
        )
        .overlay(alignment: .topTrailing) {
            if hovering {
                HStack(spacing: 5) {
                    Button {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(record.text, forType: .string)
                        copied = true
                        Task { @MainActor in
                            try? await Task.sleep(for: .seconds(1.2))
                            copied = false
                        }
                    } label: {
                        Image(systemName: copied ? "checkmark" : "doc.on.doc")
                            .contentTransition(.symbolEffect(.replace))
                    }
                    .buttonStyle(RowActionButtonStyle())
                    Button {
                        withAnimation(Theme.spring) { Store.shared.deleteRecord(record) }
                    } label: {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(RowActionButtonStyle(destructive: true))
                }
                .padding(8)
                .transition(.opacity)
            }
        }
        .onHover { hovering = $0 }
        .animation(Theme.springFast, value: hovering)
    }
}
