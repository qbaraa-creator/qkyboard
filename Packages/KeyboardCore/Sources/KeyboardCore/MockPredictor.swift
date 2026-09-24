import Foundation

/// Static word list standing in for the prediction engine during the typing prototype
/// (UX spec §50 item 10). It exercises the bar's states and mixed-language behaviour;
/// it does not learn. Replaced in Phase 2.
public struct MockPredictor: Sendable {
    public init() {}

    static let words: [String] = [
        // Arabic
        "المحمصة", "المحصول", "المحاصيل", "التحميص", "التركيب", "التنفيذ", "الاستلام", "التقرير",
        "المبيعات", "الشهر", "القادم", "الاتفاق", "السابق", "الرجاء", "إرسال", "أرسل", "راجع",
        "متى", "سيتم", "قبل", "بعد", "الصور", "التفاصيل", "شكرا", "إن", "شاء", "الله", "مرحبا",
        "العميل", "الطلب", "الفاتورة", "المخزون", "الاجتماع", "اليوم", "غدا",
        // English
        "forecast", "forecasted", "foreign", "report", "file", "inventory", "invoice", "please",
        "send", "details", "the", "thanks", "meeting", "tomorrow", "today", "roastery", "ready",
        "review", "before", "after", "follow", "update", "schedule",
    ]

    /// Tiny next-word table for the empty-token state (§30 State A).
    static let nextWords: [String: [String]] = [
        "سيتم": ["التركيب", "التنفيذ", "الاستلام"],
        "الـ": ["forecast", "report", "file"],
        "راجع": ["التقرير", "inventory", "المخزون"],
        "أرسل": ["التقرير", "الفاتورة", "forecast"],
        "please": ["send", "review", "update"],
        "the": ["report", "forecast", "inventory"],
        "إن": ["شاء"],
        "شاء": ["الله"],
    ]

    /// Up to three candidates for the text before the cursor, drawn from both languages
    /// regardless of the active layout (§34).
    public func candidates(before: String?) -> [String] {
        let token = TextEditing.currentToken(before: before)
        if token.isEmpty {
            let previous = before?.split(whereSeparator: \.isWhitespace).last.map(String.init) ?? ""
            return Self.nextWords[previous.lowercased()] ?? []
        }
        let key = Self.normalize(token)
        let matches = Self.words.filter { Self.normalize($0).hasPrefix(key) && $0 != token.lowercased() }
            .sorted { $0.count < $1.count }
        let capitalized = token.first?.isUppercase == true
        var result = [token] // §30 State C: the exact typed word is always available.
        for word in matches where result.count < 3 {
            result.append(capitalized ? word.prefix(1).uppercased() + word.dropFirst() : word)
        }
        return result
    }

    /// Matching-only normalization (PRD §21): folds alef/hamza/yaa variants, tatweel and
    /// case. Never applied to inserted text.
    static func normalize(_ s: String) -> String {
        var out = ""
        for c in s.lowercased() {
            switch c {
            case "أ", "إ", "آ", "ٱ": out.append("ا")
            case "ى": out.append("ي")
            case "ؤ": out.append("و")
            case "ئ": out.append("ي")
            case "ـ": continue
            default: out.append(c)
            }
        }
        return out
    }
}
