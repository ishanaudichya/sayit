import AppKit
import SwiftUI

/// SayIt design system — "Ink & Citron", adaptive.
///
/// Two grounds, one signal: warm paper in light mode, warm ink in dark, and
/// citron reserved for voice and primary action in both. Tokens are dynamic
/// NSColors, so every view follows the app's appearance automatically.
enum Theme {
    // MARK: Surfaces

    /// Window ground.
    static let ground = dynamic(light: (0.965, 0.957, 0.937), dark: (0.067, 0.067, 0.075))
    /// Cards and raised surfaces.
    static let raised = dynamic(light: (1.0, 1.0, 1.0), dark: (0.104, 0.104, 0.116))
    /// Wells: text fields, insets.
    static let sunken = dynamic(light: (0.922, 0.912, 0.886), dark: (0.042, 0.042, 0.048))

    // MARK: Content

    /// Primary text.
    static let text = dynamic(light: (0.106, 0.106, 0.122), dark: (0.949, 0.937, 0.910))
    /// Secondary text.
    static var textDim: Color { text.opacity(0.58) }
    /// Tertiary text / hints.
    static var textFaint: Color { text.opacity(0.34) }

    // MARK: Signal

    /// Accent for text and icons — olive in light (citron is too pale on
    /// paper), citron in dark.
    static let accent = dynamic(light: (0.369, 0.435, 0.043), dark: (0.816, 0.945, 0.247))
    /// The brand fill. Constant in both modes; pair with `onCitron` labels.
    static let citron = Color(red: 0.816, green: 0.945, blue: 0.247)
    /// Label color on citron fills.
    static let onCitron = Color(red: 0.09, green: 0.09, blue: 0.05)
    /// Errors and destructive state.
    static let coral = dynamic(light: (0.82, 0.26, 0.19), dark: (1.0, 0.44, 0.35))

    // MARK: Lines & fills

    static let hairline = dynamic(light: (0, 0, 0), dark: (1, 1, 1), lightAlpha: 0.10, darkAlpha: 0.08)
    static let fillFaint = dynamic(light: (0, 0, 0), dark: (1, 1, 1), lightAlpha: 0.045, darkAlpha: 0.05)
    static let fillSoft = dynamic(light: (0, 0, 0), dark: (1, 1, 1), lightAlpha: 0.085, darkAlpha: 0.12)

    private static func dynamic(
        light: (Double, Double, Double),
        dark: (Double, Double, Double),
        lightAlpha: Double = 1,
        darkAlpha: Double = 1
    ) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            let (r, g, b) = isDark ? dark : light
            return NSColor(srgbRed: r, green: g, blue: b, alpha: isDark ? darkAlpha : lightAlpha)
        })
    }

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

// MARK: - Appearance

/// User-selectable appearance: system, or forced light/dark.
enum Appearance: String, CaseIterable, Identifiable {
    case system, light, dark

    var id: String { rawValue }

    var label: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }

    @MainActor
    func apply() {
        switch self {
        case .system: NSApp.appearance = nil
        case .light: NSApp.appearance = NSAppearance(named: .aqua)
        case .dark: NSApp.appearance = NSAppearance(named: .darkAqua)
        }
    }

    @MainActor
    static func applyStored() {
        let raw = UserDefaults.standard.string(forKey: "appearance") ?? "system"
        (Appearance(rawValue: raw) ?? .system).apply()
    }
}
