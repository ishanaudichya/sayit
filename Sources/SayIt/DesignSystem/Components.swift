import SwiftUI

// MARK: - Wordmark

/// "sayit" + citron tick. The brand, lowercase and quiet.
struct Wordmark: View {
    var size: CGFloat = 17

    var body: some View {
        HStack(alignment: .lastTextBaseline, spacing: size * 0.14) {
            Text("sayit")
                .font(.system(size: size, weight: .bold))
                .tracking(size * -0.03)
                .foregroundStyle(Theme.bone)
            Circle()
                .fill(Theme.citron)
                .frame(width: size * 0.30, height: size * 0.30)
        }
    }
}

// MARK: - Wave mark

/// The five-bar voice glyph. Static by default; `animated` gives it a slow
/// idle breath (driven by TimelineView, so it pauses off-screen).
struct WaveMark: View {
    var height: CGFloat = 36
    var color: Color = Theme.citron
    var animated = false

    private let profile: [CGFloat] = [0.30, 0.54, 0.86, 0.54, 0.30]

    var body: some View {
        Group {
            if animated {
                TimelineView(.animation(minimumInterval: 1.0 / 20.0)) { timeline in
                    bars(at: timeline.date.timeIntervalSinceReferenceDate)
                }
            } else {
                bars(at: 0)
            }
        }
        .frame(height: height)
    }

    private func bars(at time: TimeInterval) -> some View {
        let barWidth = height * 0.13
        return HStack(spacing: height * 0.115) {
            ForEach(profile.indices, id: \.self) { index in
                let wobble = animated
                    ? 0.82 + 0.18 * sin(time * 2.1 + Double(index) * 1.15)
                    : 1.0
                Capsule()
                    .fill(color)
                    .frame(width: barWidth, height: max(barWidth, height * profile[index] * wobble))
            }
        }
        .frame(height: height)
    }
}

// MARK: - Buttons

/// Citron capsule, ink label. The one loud control on any screen.
struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(Theme.ink)
            .padding(.horizontal, 18)
            .padding(.vertical, 9)
            .background(Capsule().fill(Theme.citron))
            .brightness(configuration.isPressed ? -0.08 : 0)
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(Theme.springFast, value: configuration.isPressed)
    }
}

/// Hairline capsule, bone label. Everything secondary.
struct GhostButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(Theme.bone)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(Color.white.opacity(configuration.isPressed ? 0.10 : 0.045))
            )
            .overlay(Capsule().strokeBorder(Theme.hairline, lineWidth: 1))
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(Theme.springFast, value: configuration.isPressed)
    }
}

/// Bare text button for tertiary actions.
struct LinkButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(configuration.isPressed ? Theme.bone : Theme.boneDim)
    }
}

// MARK: - Card

struct CardBackground: ViewModifier {
    var padding: CGFloat = 18

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                    .fill(Theme.inkRaised)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                    .strokeBorder(Theme.hairline, lineWidth: 1)
            )
    }
}

extension View {
    func card(padding: CGFloat = 18) -> some View {
        modifier(CardBackground(padding: padding))
    }
}

// MARK: - Toggle

/// Capsule toggle: citron track when on, spring-loaded knob.
struct ThemeToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack {
            configuration.label
                .font(Theme.body())
                .foregroundStyle(Theme.bone)
            Spacer()
            Capsule()
                .fill(configuration.isOn ? Theme.citron : Color.white.opacity(0.12))
                .frame(width: 36, height: 21)
                .overlay(alignment: configuration.isOn ? .trailing : .leading) {
                    Circle()
                        .fill(configuration.isOn ? Theme.ink : Theme.bone)
                        .frame(width: 15, height: 15)
                        .padding(3)
                }
                .animation(Theme.springFast, value: configuration.isOn)
                .onTapGesture { configuration.isOn.toggle() }
        }
    }
}

// MARK: - Step dots

/// Onboarding progress: the active step stretches into a citron pill.
struct StepDots: View {
    var count: Int
    var current: Int

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<count, id: \.self) { index in
                Capsule()
                    .fill(index == current ? Theme.citron : Color.white.opacity(0.14))
                    .frame(width: index == current ? 22 : 6, height: 6)
            }
        }
        .animation(Theme.spring, value: current)
    }
}

// MARK: - Status chip

struct StatusChip: View {
    var label: String
    var color: Color

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
            Text(label)
                .font(.system(size: 11.5, weight: .medium))
                .foregroundStyle(Theme.boneDim)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Capsule().fill(Color.white.opacity(0.05)))
        .overlay(Capsule().strokeBorder(Theme.hairline, lineWidth: 1))
    }
}

// MARK: - Key cap

/// A drawn fn keycap — used in onboarding and the dashboard hero.
struct KeyCap: View {
    var label: String = "fn"
    var symbol: String = "globe"
    var size: CGFloat = 44

    var body: some View {
        VStack(spacing: size * 0.09) {
            Image(systemName: symbol)
                .font(.system(size: size * 0.26, weight: .medium))
            Text(label)
                .font(.system(size: size * 0.24, weight: .semibold))
        }
        .foregroundStyle(Theme.bone)
        .frame(width: size, height: size)
        .background(
            RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
                .fill(LinearGradient(
                    colors: [Color.white.opacity(0.14), Color.white.opacity(0.05)],
                    startPoint: .top, endPoint: .bottom
                ))
        )
        .overlay(
            RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
                .strokeBorder(Color.white.opacity(0.16), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.5), radius: 3, y: 2)
    }
}

// MARK: - Permission row (shared by onboarding + dashboard health strip)

struct PermissionState: View {
    var granted: Bool

    var body: some View {
        Image(systemName: granted ? "checkmark.circle.fill" : "circle.dashed")
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(granted ? Theme.citron : Theme.boneFaint)
            .contentTransition(.symbolEffect(.replace))
    }
}
