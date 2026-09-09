import SwiftUI

/// A safe place to practice: a scratchpad, live status, and phrases that show
/// off what smart formatting fixes.
struct TryItView: View {
    @Environment(AppController.self) private var app
    @State private var scratch = ""

    private let samples = [
        "\u{201C}um so basically the meeting went really well\u{201D}",
        "\u{201C}send it by Friday — no wait, Thursday\u{201D}",
        "\u{201C}thanks again new line talk soon\u{201D}",
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Try it")
                    .font(Theme.display(24))
                    .tracking(-0.6)
                    .foregroundStyle(Theme.text)
                HStack(spacing: 7) {
                    Text("Click the scratchpad, hold")
                        .foregroundStyle(Theme.textDim)
                    KeyCap(size: 26)
                    Text("speak, release.")
                        .foregroundStyle(Theme.textDim)
                }
                .font(Theme.body(12.5))
            }
            .padding(.top, 8)

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    SectionHeader(title: "Scratchpad")
                    Spacer()
                    if !scratch.isEmpty {
                        Button("Clear") { scratch = "" }
                            .buttonStyle(LinkButtonStyle())
                    }
                }
                TextEditor(text: $scratch)
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.text)
                    .scrollContentBackground(.hidden)
                    .padding(10)
                    .frame(maxHeight: .infinity)
                    .well(focused: app.status == .recording)
            }
            .card(padding: 14)
            .frame(maxHeight: .infinity)

            HStack(spacing: 10) {
                StatusChip(label: statusLabel, color: statusColor)
                WaveMark(height: 16, animated: app.status == .recording)
                Spacer()
            }

            VStack(alignment: .leading, spacing: 8) {
                SectionHeader(title: "Things to try saying")
                ForEach(samples, id: \.self) { sample in
                    HStack(spacing: 8) {
                        Circle()
                            .fill(Theme.citron)
                            .frame(width: 4, height: 4)
                        Text(sample)
                            .font(Theme.body(12))
                            .foregroundStyle(Theme.textDim)
                    }
                }
                Text("Smart formatting removes the filler, applies the correction, and honors “new line”.")
                    .font(.system(size: 10.5))
                    .foregroundStyle(Theme.textFaint)
                    .padding(.top, 2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .card(padding: 14)
        }
        .padding(22)
    }

    private var statusLabel: String {
        switch app.status {
        case .idle: return "Ready"
        case .recording: return "Listening…"
        case .finishing: return "Finishing"
        case .inserted: return "Inserted"
        case .error(let message): return message
        }
    }

    private var statusColor: Color {
        switch app.status {
        case .idle, .recording, .inserted: return Theme.accent
        case .finishing: return Theme.textFaint
        case .error: return Theme.coral
        }
    }
}
