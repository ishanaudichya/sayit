import SwiftUI

/// SayIt's design system — "Ink & Citron".
///
/// One committed look everywhere: warm near-black ink surfaces, bone-white
/// type, hairline strokes, and a single signal color (citron) reserved for
/// voice and primary action. Nothing else gets to be loud.
enum Theme {
    // MARK: Palette

    /// Window ground.
    static let ink = Color(red: 0.067, green: 0.067, blue: 0.075)
    /// Cards and raised surfaces.
    static let inkRaised = Color(red: 0.104, green: 0.104, blue: 0.116)
    /// Wells: text fields, insets.
    static let inkSunken = Color(red: 0.042, green: 0.042, blue: 0.048)
    /// Primary text.
    static let bone = Color(red: 0.949, green: 0.937, blue: 0.910)
    /// Secondary text.
    static let boneDim = bone.opacity(0.56)
    /// Tertiary text / disabled.
    static let boneFaint = bone.opacity(0.30)
    /// The signal: voice, action, success. Use sparingly.
    static let citron = Color(red: 0.816, green: 0.945, blue: 0.247)
    /// Errors and destructive state.
    static let coral = Color(red: 1.0, green: 0.44, blue: 0.35)
    /// 1px strokes on dark.
    static let hairline = Color.white.opacity(0.08)

    // MARK: Type

    static func display(_ size: CGFloat) -> Font {
        .system(size: size, weight: .bold)
    }
    static func title(_ size: CGFloat) -> Font {
        .system(size: size, weight: .semibold)
    }
    static func body(_ size: CGFloat = 13) -> Font {
        .system(size: size, weight: .regular)
    }
    static func mono(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }

    // MARK: Shape

    enum Radius {
        static let card: CGFloat = 14
        static let control: CGFloat = 9
        static let well: CGFloat = 10
    }

    // MARK: Motion

    /// House spring for state changes.
    static let spring = Animation.spring(response: 0.32, dampingFraction: 0.78)
    /// Snappier spring for presses and micro-interactions.
    static let springFast = Animation.spring(response: 0.22, dampingFraction: 0.82)
}
