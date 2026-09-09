import Foundation

/// Deterministic text transforms — instant, predictable, applied before any
/// model sees the transcript.
enum TextRules {
    private static let spokenPunctuation: [(pattern: String, replacement: String)] = [
        ("\\s*\\bnew paragraph\\b\\s*", "\n\n"),
        ("\\s*\\bnew line\\b\\s*", "\n"),
        ("\\s*\\bfull stop\\b", "."),
        ("\\s*\\bperiod\\b", "."),
        ("\\s*\\bcomma\\b", ","),
        ("\\s*\\bquestion mark\\b", "?"),
        ("\\s*\\bexclamation (?:mark|point)\\b", "!"),
        ("\\s*\\bsemicolon\\b", ";"),
        ("\\s*\\bopen quote\\b\\s*", " \u{201C}"),
        ("\\s*\\bclose quote\\b", "\u{201D}"),
    ]

    /// "send it by five comma then call me period" → "send it by five, then call me."
    static func applySpokenPunctuation(_ text: String) -> String {
        var result = text
        for rule in spokenPunctuation {
            result = result.replacingOccurrences(
                of: "(?i)" + rule.pattern,
                with: NSRegularExpression.escapedTemplate(for: rule.replacement),
                options: .regularExpression
            )
        }
        return result.replacingOccurrences(of: " {2,}", with: " ", options: .regularExpression)
    }
}

/// The user's punctuation preference, persisted as "punctuationMode".
enum PunctuationMode: String, CaseIterable, Identifiable {
    case auto, spoken, minimal

    var id: String { rawValue }

    var label: String {
        switch self {
        case .auto: return "Auto"
        case .spoken: return "Spoken"
        case .minimal: return "Minimal"
        }
    }

    var caption: String {
        switch self {
        case .auto: return "The speech engine punctuates for you."
        case .spoken: return "You dictate it: \u{201C}comma\u{201D}, \u{201C}period\u{201D}, \u{201C}question mark\u{201D}, \u{201C}new line\u{201D}."
        case .minimal: return "Light touch — only essential punctuation (uses smart formatting)."
        }
    }

    static var current: PunctuationMode {
        PunctuationMode(rawValue: UserDefaults.standard.string(forKey: "punctuationMode") ?? "auto") ?? .auto
    }
}
