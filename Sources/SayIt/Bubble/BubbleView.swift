import SwiftUI

/// The dictation pill: ink capsule, citron waveform, citron glow while
/// listening. Pops in with a spring, morphs into a check on insert.
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
                    .opacity(0.3)
            case .inserted:
                ZStack {
                    Circle()
                        .fill(Pill.citron)
                        .frame(width: 22, height: 22)
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .heavy))
                        .foregroundStyle(Pill.ink)
                }
                .transition(.scale(scale: 0.4).combined(with: .opacity))
            case .error(let message):
                Label(message, systemImage: "exclamationmark.triangle.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Pill.coral)
                    .lineLimit(1)
                    .padding(.horizontal, 10)
            case .idle:
                Color.clear
            }
        }
        .frame(width: 236, height: 42)
        .background(
            Capsule(style: .continuous)
                .fill(Pill.ink.opacity(0.94))
        )
        .overlay(
            Capsule(style: .continuous)
                .strokeBorder(strokeColor, lineWidth: 1)
        )
        .shadow(color: glowColor, radius: 16, y: 3)
        .scaleEffect(app.status == .idle ? 0.88 : 1)
        .animation(Theme.springFast, value: app.status)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var strokeColor: Color {
        switch app.status {
        case .recording: return Pill.citron.opacity(0.28)
        case .error: return Pill.coral.opacity(0.35)
        default: return Pill.hairline
        }
    }

    private var glowColor: Color {
        switch app.status {
        case .recording: return Pill.citron.opacity(0.20)
        case .inserted: return Pill.citron.opacity(0.25)
        case .error: return Pill.coral.opacity(0.25)
        default: return Color.black.opacity(0.35)
        }
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
                        with: .color(Pill.citron)
                    )
                    x += barWidth + spacing
                }
            }
        }
        .frame(width: 160, height: 26)
    }
}

/// The pill floats over arbitrary wallpapers, so it stays ink-dark in both
/// appearance modes — its palette is fixed, not adaptive.
private enum Pill {
    static let ink = Color(red: 0.067, green: 0.067, blue: 0.075)
    static let citron = Color(red: 0.816, green: 0.945, blue: 0.247)
    static let coral = Color(red: 1.0, green: 0.44, blue: 0.35)
    static let hairline = Color.white.opacity(0.12)
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
