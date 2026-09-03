import SwiftUI

/// The black pill shown while dictating: live waveform while recording,
/// then a brief checkmark / error state.
struct BubbleView: View {
    @Environment(AppController.self) private var app

    var body: some View {
        ZStack {
            switch app.status {
            case .recording:
                WaveformView(level: app.audioLevel)
                    .transition(.opacity)
            case .finishing:
                WaveformView(level: 0)
                    .opacity(0.35)
            case .inserted:
                Image(systemName: "checkmark")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
                    .transition(.scale.combined(with: .opacity))
            case .error(let message):
                Label(message, systemImage: "exclamationmark.triangle.fill")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .padding(.horizontal, 8)
            case .idle:
                Color.clear
            }
        }
        .frame(width: 232, height: 40)
        .background(
            Capsule(style: .continuous)
                .fill(Color.black.opacity(0.88))
        )
        .overlay(
            Capsule(style: .continuous)
                .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.35), radius: 14, y: 4)
        .animation(.spring(duration: 0.25), value: app.status)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// A scrolling voice waveform drawn as a single Canvas layer — one draw call
/// per frame instead of 30 animated views. TimelineView pauses automatically
/// when the panel is hidden, so this costs nothing while idle.
struct WaveformView: View {
    var level: Float

    @State private var history = WaveHistory()

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
            Canvas { context, size in
                history.step(now: timeline.date.timeIntervalSinceReferenceDate, level: CGFloat(level))
                let barWidth: CGFloat = 2.5
                let spacing: CGFloat = 2.5
                let total = CGFloat(history.bars.count) * (barWidth + spacing) - spacing
                var x = (size.width - total) / 2
                for value in history.bars {
                    let height = 3 + 21 * value
                    let rect = CGRect(x: x, y: (size.height - height) / 2, width: barWidth, height: height)
                    context.fill(
                        Path(roundedRect: rect, cornerRadius: barWidth / 2),
                        with: .color(.white.opacity(0.95))
                    )
                    x += barWidth + spacing
                }
            }
        }
        .frame(width: 160, height: 26)
    }
}

/// Ring buffer of recent levels; stepped at most every 50ms.
private final class WaveHistory {
    var bars: [CGFloat] = Array(repeating: 0.06, count: 30)
    private var lastStep: TimeInterval = 0

    func step(now: TimeInterval, level: CGFloat) {
        guard now - lastStep >= 0.05 else { return }
        lastStep = now
        bars.removeFirst()
        bars.append(max(0.06, min(1, level) * .random(in: 0.75...1.0)))
    }
}
