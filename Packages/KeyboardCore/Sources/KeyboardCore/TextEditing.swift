import Foundation

/// Stateless text rules that only need the text before the cursor.
public enum TextEditing {
    /// Whether English input should start capitalized at this cursor position.
    public static func shouldAutoCapitalize(before: String?, mode: AutocapMode) -> Bool {
        let before = before ?? ""
        switch mode {
        case .none:
            return false
        case .allCharacters:
            return true
        case .words:
            guard let last = before.last else { return true }
            return last.isWhitespace
        case .sentences:
            guard let last = before.last else { return true }
            if last.isNewline { return true }
            guard last.isWhitespace else { return false }
            let trimmed = before.trimmingCharacters(in: .whitespaces)
            guard let end = trimmed.last else { return true }
            return end.isNewline || sentenceTerminators.contains(end)
        }
    }

    static let sentenceTerminators: Set<Character> = [".", "!", "?", "؟", "…"]

    /// Double-space → ". " applies only right after a word, never after punctuation or a
    /// second space, so typing extra spaces stays predictable.
    public static func canInsertPeriodOnDoubleSpace(before: String?) -> Bool {
        guard let before, before.last == " " else { return false }
        let previous = before.dropLast().last
        guard let previous else { return false }
        return previous.isLetter || previous.isNumber
    }

    /// The partial word directly before the cursor: letters, digits and tatweel, stopping
    /// at whitespace, punctuation, or a switch between Arabic and Latin script, so both
    /// "راجع الـ fore" and "الـfore" give "fore".
    public static func currentToken(before: String?) -> String {
        guard let before, let last = before.last else { return "" }
        let script = isArabic(last)
        var start = before.endIndex
        while start > before.startIndex {
            let prev = before.index(before: start)
            let c = before[prev]
            guard c.isLetter || c.isNumber || c == "ـ", isArabic(c) == script else { break }
            start = prev
        }
        return String(before[start...])
    }

    public static func isArabic(_ c: Character) -> Bool {
        c.unicodeScalars.contains { (0x0600...0x06FF).contains($0.value) || (0x0750...0x077F).contains($0.value) }
    }

    /// Characters to delete to remove the word behind the cursor, plus any whitespace
    /// that directly precedes the cursor.
    public static func wordDeletionLength(before: String?) -> Int {
        guard let before, !before.isEmpty else { return 1 }
        var count = 0
        var index = before.endIndex
        while index > before.startIndex {
            let prev = before.index(before: index)
            guard before[prev].isWhitespace else { break }
            count += 1
            index = prev
        }
        // Delete one run of the same class: "hello, world" → "world", then ",", then "hello".
        var runIsPunctuation: Bool?
        while index > before.startIndex {
            let prev = before.index(before: index)
            let c = before[prev]
            if c.isWhitespace { break }
            let isPunctuation = c.isPunctuation || c.isSymbol
            if let runIsPunctuation, runIsPunctuation != isPunctuation { break }
            runIsPunctuation = isPunctuation
            count += 1
            index = prev
        }
        return max(count, 1)
    }
}

/// Hold-to-delete timing. Speeds up gradually and only moves to whole words after a
/// sustained hold, so a long press never jumps to deleting large chunks (PRD §14).
public struct DeleteRepeatSchedule: Sendable {
    public enum Unit: Sendable, Equatable { case character, word }

    public var initialDelay: TimeInterval = 0.45
    public var startInterval: TimeInterval = 0.10
    public var fastestInterval: TimeInterval = 0.05
    public var accelerationTicks: Int = 12
    public var wordModeAfterTicks: Int = 24
    public var wordInterval: TimeInterval = 0.2

    public init() {}

    /// `tick` counts repeats after the initial delay, starting at 0.
    public func step(tick: Int) -> (unit: Unit, interval: TimeInterval) {
        if tick >= wordModeAfterTicks {
            return (.word, wordInterval)
        }
        let progress = min(1, Double(tick) / Double(accelerationTicks))
        return (.character, startInterval - (startInterval - fastestInterval) * progress)
    }
}
