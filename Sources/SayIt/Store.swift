import Foundation
import Observation

// MARK: - Models

struct DictationRecord: Codable, Identifiable, Equatable {
    var id = UUID()
    var date = Date()
    /// What the speech engine heard, before cleanup.
    var raw: String
    /// What was actually typed.
    var text: String
    var duration: TimeInterval
    var wordCount: Int

    var wpm: Int {
        duration > 1 ? Int((Double(wordCount) / (duration / 60)).rounded()) : 0
    }
}

struct DictionaryEntry: Codable, Identifiable, Equatable {
    var id = UUID()
    /// What you say.
    var spoken: String
    /// What gets typed. Empty = a vocabulary word (spelling preference only).
    var replacement: String

    var isVocabulary: Bool {
        replacement.trimmingCharacters(in: .whitespaces).isEmpty
    }
}

// MARK: - Store

/// Local persistence for history, the dictionary, and lifetime stats.
/// Plain JSON in Application Support — private, inspectable, no database.
@MainActor
@Observable
final class Store {
    static let shared = Store()

    private(set) var records: [DictationRecord] = []
    private(set) var entries: [DictionaryEntry] = []
    private(set) var lifetimeWords: Int
    private(set) var lifetimeDictations: Int

    private static let maxRecords = 500
    private let directory: URL

    private var recordsURL: URL { directory.appendingPathComponent("history.json") }
    private var entriesURL: URL { directory.appendingPathComponent("dictionary.json") }

    private init() {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        directory = base.appendingPathComponent("SayIt", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        // Seeded from the pre-Store counters so existing numbers carry over.
        lifetimeWords = UserDefaults.standard.integer(forKey: "stats.totalWords")
        lifetimeDictations = UserDefaults.standard.integer(forKey: "stats.totalDictations")
        records = Self.read([DictationRecord].self, from: directory.appendingPathComponent("history.json")) ?? []
        entries = Self.read([DictionaryEntry].self, from: directory.appendingPathComponent("dictionary.json")) ?? []
    }

    // MARK: History

    func addRecord(raw: String, text: String, duration: TimeInterval) {
        let words = text.split { $0.isWhitespace || $0.isNewline }.count
        records.insert(DictationRecord(raw: raw, text: text, duration: duration, wordCount: words), at: 0)
        if records.count > Self.maxRecords {
            records.removeLast(records.count - Self.maxRecords)
        }
        lifetimeWords += words
        lifetimeDictations += 1
        UserDefaults.standard.set(lifetimeWords, forKey: "stats.totalWords")
        UserDefaults.standard.set(lifetimeDictations, forKey: "stats.totalDictations")
        save(records, to: recordsURL)
    }

    func deleteRecord(_ record: DictationRecord) {
        records.removeAll { $0.id == record.id }
        save(records, to: recordsURL)
    }

    func clearRecords() {
        records.removeAll()
        save(records, to: recordsURL)
    }

    /// Average words-per-minute over recent dictations long enough to measure.
    var averageWPM: Int {
        let usable = records.prefix(50).filter { $0.duration > 2 }
        guard !usable.isEmpty else { return 0 }
        return usable.map(\.wpm).reduce(0, +) / usable.count
    }

    // MARK: Dictionary

    func addEntry(spoken: String, replacement: String) {
        let spoken = spoken.trimmingCharacters(in: .whitespaces)
        guard !spoken.isEmpty else { return }
        entries.insert(DictionaryEntry(spoken: spoken, replacement: replacement.trimmingCharacters(in: .whitespaces)), at: 0)
        save(entries, to: entriesURL)
    }

    func deleteEntry(_ entry: DictionaryEntry) {
        entries.removeAll { $0.id == entry.id }
        save(entries, to: entriesURL)
    }

    /// Deterministic text replacements ("brb" → "be right back"), applied
    /// before any model touches the transcript. Whole-word, case-insensitive.
    func applyReplacements(to text: String) -> String {
        var result = text
        for entry in entries where !entry.isVocabulary {
            let pattern = "(?i)\\b" + NSRegularExpression.escapedPattern(for: entry.spoken) + "\\b"
            let template = NSRegularExpression.escapedTemplate(for: entry.replacement)
            result = result.replacingOccurrences(of: pattern, with: template, options: .regularExpression)
        }
        return result
    }

    /// Spelling preferences fed to the smart-formatting model.
    var vocabularyWords: [String] {
        entries.filter(\.isVocabulary).map(\.spoken)
    }

    // MARK: IO

    private static func read<T: Decodable>(_ type: T.Type, from url: URL) -> T? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }

    private func save<T: Encodable>(_ value: T, to url: URL) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        try? data.write(to: url, options: .atomic)
    }
}
