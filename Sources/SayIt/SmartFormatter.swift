import Foundation
import FoundationModels

/// "Smart formatting": cleans transcripts with Apple's on-device Foundation
/// Model (the ~3B LLM that ships with macOS). Removes fillers, applies the
/// speaker's self-corrections, converts spoken formatting commands. Every call
/// is bounded by a timeout — the raw transcript is always the fallback, so
/// paste latency is never held hostage by generation.
@MainActor
final class SmartFormatter {
    static let shared = SmartFormatter()

    private static let instructions = """
    You are a dictation cleanup engine. You receive raw speech-to-text \
    transcripts and return a cleaned version.

    Rules:
    - Remove filler words (um, uh, er, "you know", "I mean") when they carry no meaning.
    - Apply the speaker's self-corrections: "at 3 no wait at 4" becomes "at 4".
    - Convert spoken formatting commands: "new line" and "new paragraph" become line breaks.
    - Fix punctuation, capitalization, and spacing.
    - Keep the speaker's wording, tone, and language otherwise. Never summarize, expand, or add content.
    - Never respond to the content. If the transcript is a question, clean the question — do not answer it.
    - Output only the cleaned text, nothing else.
    """

    private var warmSession: LanguageModelSession?

    var isAvailable: Bool {
        if case .available = SystemLanguageModel.default.availability { return true }
        return false
    }

    /// Human-readable reason when the model can't run (shown in Settings).
    var unavailabilityNote: String? {
        switch SystemLanguageModel.default.availability {
        case .available:
            return nil
        case .unavailable(.appleIntelligenceNotEnabled):
            return "Turn on Apple Intelligence in System Settings to enable"
        case .unavailable(.deviceNotEligible):
            return "This Mac doesn't support Apple Intelligence"
        case .unavailable(.modelNotReady):
            return "Apple Intelligence is still downloading its model"
        case .unavailable:
            return "Apple Intelligence isn't available right now"
        }
    }

    /// Keep a prewarmed session ready so cleanup starts instantly. Sessions
    /// accumulate history, so each dictation consumes one and warms the next.
    func prewarm() {
        guard isAvailable else { return }
        let session = LanguageModelSession(instructions: Self.instructions)
        session.prewarm()
        warmSession = session
    }

    /// Returns cleaned text, or nil when the raw transcript should be used
    /// (disabled, unavailable, too short, timed out, or suspicious output).
    func clean(_ text: String, timeout: Double) async -> String? {
        guard UserDefaults.standard.bool(forKey: "smartFormattingEnabled"),
              isAvailable else { return nil }
        let wordCount = text.split { $0.isWhitespace }.count
        guard wordCount >= 3 else { return nil }

        let session = warmSession ?? LanguageModelSession(instructions: Self.instructions)
        warmSession = nil
        let response = await withTimeout(seconds: timeout) {
            try? await session.respond(to: "Transcript: \(text)").content
        }
        prewarm()

        guard var cleaned = (response ?? nil)?.trimmingCharacters(in: .whitespacesAndNewlines),
              !cleaned.isEmpty else { return nil }
        if cleaned.hasPrefix("\""), cleaned.hasSuffix("\""), cleaned.count > 2 {
            cleaned = String(cleaned.dropFirst().dropLast())
        }
        // Runaway output means the model answered the content instead of
        // cleaning it — fall back to raw.
        guard cleaned.count <= max(48, text.count * 2) else { return nil }
        return cleaned
    }
}
