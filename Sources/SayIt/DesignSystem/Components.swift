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
                .foregroundStyle(Theme.text)
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
    var color: Color = Theme.accent
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

/// Citron capsule, dark label. The one loud control on any screen.
struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(Theme.onCitron)
            .padding(.horizontal, 18)
            .padding(.vertical, 9)
            .background(Capsule().fill(Theme.citron))
            .brightness(configuration.isPressed ? -0.08 : 0)
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(Theme.springFast, value: configuration.isPressed)
    }
}

/// Hairline capsule. Everything secondary.
struct GhostButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(Theme.text)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                Capsule().fill(configuration.isPressed ? Theme.fillSoft : Theme.fillFaint)
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
            .foregroundStyle(configuration.isPressed ? Theme.text : Theme.textDim)
    }
}

/// Icon-only button that appears on hover in list rows.
struct RowActionButtonStyle: ButtonStyle {
    var destructive = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(destructive ? Theme.coral : Theme.textDim)
            .frame(width: 24, height: 24)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(configuration.isPressed ? Theme.fillSoft : Theme.fillFaint)
            )
            .scaleEffect(configuration.isPressed ? 0.92 : 1)
            .animation(Theme.springFast, value: configuration.isPressed)
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
                    .fill(Theme.raised)
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

// MARK: - Well (inset text areas)

struct WellBackground: ViewModifier {
    var focused = false

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.well, style: .continuous)
                    .fill(Theme.sunken)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.well, style: .continuous)
                    .strokeBorder(focused ? Theme.citron.opacity(0.6) : Theme.hairline, lineWidth: 1)
            )
    }
}

extension View {
    func well(focused: Bool = false) -> some View {
        modifier(WellBackground(focused: focused))
    }
}

// MARK: - Toggle

/// Capsule toggle: citron track when on, spring-loaded knob.
struct ThemeToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack {
            configuration.label
                .font(Theme.body())
                .foregroundStyle(Theme.text)
            Spacer()
            Capsule()
                .fill(configuration.isOn ? Theme.citron : Theme.fillSoft)
                .frame(width: 36, height: 21)
                .overlay(alignment: configuration.isOn ? .trailing : .leading) {
                    Circle()
                        .fill(configuration.isOn ? Theme.onCitron : Color.white)
                        .shadow(color: .black.opacity(0.25), radius: 1, y: 1)
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
                    .fill(index == current ? Theme.citron : Theme.fillSoft)
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
                .foregroundStyle(Theme.textDim)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Capsule().fill(Theme.fillFaint))
        .overlay(Capsule().strokeBorder(Theme.hairline, lineWidth: 1))
    }
}

// MARK: - Key cap

/// A drawn fn keycap — used in onboarding and the home hero.
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
        .foregroundStyle(Theme.text)
        .frame(width: size, height: size)
        .background(
            RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
                .fill(Theme.fillSoft)
        )
        .overlay(
            RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
                .strokeBorder(Theme.hairline, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.18), radius: 2, y: 1.5)
    }
}

// MARK: - Permission state icon

struct PermissionState: View {
    var granted: Bool

    var body: some View {
        Image(systemName: granted ? "checkmark.circle.fill" : "circle.dashed")
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(granted ? Theme.accent : Theme.textFaint)
            .contentTransition(.symbolEffect(.replace))
    }
}

// MARK: - Section header

struct SectionHeader: View {
    var title: String

    var body: some View {
        Text(title.uppercased())
            .font(.system(size: 10, weight: .semibold))
            .tracking(1.2)
            .foregroundStyle(Theme.textFaint)
    }
}
