import Foundation

public struct LayoutContext: Sendable, Hashable {
    public var language: KeyboardLanguage
    public var page: KeyboardPage
    public var shift: ShiftState
    public var field: FieldKind
    public var returnKind: ReturnKind
    public var needsGlobe: Bool

    public init(
        language: KeyboardLanguage,
        page: KeyboardPage = .letters,
        shift: ShiftState = .off,
        field: FieldKind = .text,
        returnKind: ReturnKind = .default,
        needsGlobe: Bool = true
    ) {
        self.language = language
        self.page = page
        self.shift = shift
        self.field = field
        self.returnKind = returnKind
        self.needsGlobe = needsGlobe
    }
}

/// Pure description of every layout. Keep letter positions here and nowhere else so
/// layout tweaks from dogfooding stay a one-file change.
public enum KeyboardLayout {
    // MARK: Letter data

    /// UX spec §3 baseline: the familiar Arabic PC arrangement. The spec's sketch drops
    /// د ط ظ ذ, so they sit where the PC layout has them (ذ on long-press of د).
    /// Row sizing is prototype decision PT-01.
    static let arabicRows: [[String]] = [
        ["ض", "ص", "ث", "ق", "ف", "غ", "ع", "ه", "خ", "ح", "ج", "د"],
        ["ش", "س", "ي", "ب", "ل", "ا", "ت", "ن", "م", "ك", "ط"],
        ["ئ", "ء", "ؤ", "ر", "لا", "ى", "ة", "و", "ز", "ظ"],
    ]

    static let englishRows: [[String]] = [
        ["q", "w", "e", "r", "t", "y", "u", "i", "o", "p"],
        ["a", "s", "d", "f", "g", "h", "j", "k", "l"],
        ["z", "x", "c", "v", "b", "n", "m"],
    ]

    /// UX spec §16. No "123" page: the number row is always visible.
    static let symbolRows: [[String]] = [
        ["!", "@", "#", "$", "%", "^", "&", "*", "(", ")"],
        ["-", "_", "=", "+", "[", "]", "{", "}", "\\", "|"],
        [";", ":", "'", "\"", ",", ".", "?", "/", "…"],
    ]

    /// Arabic swaps in its own punctuation so ، ؟ ؛ are one tap away (UX spec §16–17).
    static let arabicSymbolSubstitutes: [String: String] = [";": "؛", ",": "،", "?": "؟"]

    /// Only alternates the user actually needs (UX spec §18): alef-hamza forms and ذ.
    static let arabicAlternates: [String: [String]] = [
        "ا": ["ا", "أ", "إ", "آ"],
        "د": ["د", "ذ"],
    ]

    static let englishAlternates: [String: [String]] = [
        "a": ["a", "à", "á", "â", "ä", "æ", "ã", "å"],
        "e": ["e", "è", "é", "ê", "ë"],
        "i": ["i", "ì", "í", "î", "ï"],
        "o": ["o", "ò", "ó", "ô", "ö", "õ", "ø", "œ"],
        "u": ["u", "ù", "ú", "û", "ü"],
        "n": ["n", "ñ"],
        "c": ["c", "ç"],
        "s": ["s", "ß"],
        "y": ["y", "ÿ"],
    ]

    static let symbolAlternates: [String: [String]] = [
        "$": ["$", "€", "£", "¥", "﷼"],
        "\"": ["\"", "«", "»", "“", "”"],
        "'": ["'", "‘", "’"],
        "-": ["-", "–", "—", "•"],
        "%": ["%", "‰", "٪"],
        "&": ["&", "§"],
        "/": ["/", "\\"],
    ]

    static let arabicIndicDigits: [String: String] = [
        "1": "١", "2": "٢", "3": "٣", "4": "٤", "5": "٥",
        "6": "٦", "7": "٧", "8": "٨", "9": "٩", "0": "٠",
    ]

    // MARK: Building

    public static func rows(for ctx: LayoutContext) -> [KeyboardRow] {
        switch ctx.field {
        case .number, .decimal:
            return numberPadRows(ctx)
        default:
            break
        }
        var rows = [numberRow(ctx)]
        switch ctx.page {
        case .letters:
            rows += ctx.language == .arabic ? arabicLetterRows() : englishLetterRows(ctx.shift)
        case .symbols:
            rows += symbolPageRows(ctx.language)
        }
        rows.append(bottomRow(ctx))
        return rows
    }

    static func numberRow(_ ctx: LayoutContext) -> KeyboardRow {
        let keys = ["1", "2", "3", "4", "5", "6", "7", "8", "9", "0"].map { d in
            characterKey(d, alternates: [d, arabicIndicDigits[d]!])
        }
        return KeyboardRow(keys: keys, gridUnits: 10)
    }

    static func arabicLetterRows() -> [KeyboardRow] {
        let grid = 12.0
        var rows = arabicRows.prefix(2).map { letters in
            KeyboardRow(keys: letters.map { characterKey($0, alternates: arabicAlternates[$0] ?? []) }, gridUnits: grid)
        }
        var last = arabicRows[2].map { characterKey($0, alternates: arabicAlternates[$0] ?? []) }
        last.append(deleteKey(width: 2))
        rows.append(KeyboardRow(keys: last, gridUnits: grid))
        return rows
    }

    static func englishLetterRows(_ shift: ShiftState) -> [KeyboardRow] {
        let upper = shift != .off
        func key(_ l: String) -> KeySpec {
            let alts = englishAlternates[l].map { upper ? $0.map { $0.uppercased() } : $0 } ?? []
            return KeySpec(
                id: l,
                action: .character(l),
                label: .text(upper ? l.uppercased() : l),
                alternates: alts
            )
        }
        var rows = englishRows.prefix(2).map { KeyboardRow(keys: $0.map(key), gridUnits: 10) }
        let shiftSymbol: String
        switch shift {
        case .off: shiftSymbol = "shift"
        case .on: shiftSymbol = "shift.fill"
        case .locked: shiftSymbol = "capslock.fill"
        }
        var last = [KeySpec(
            id: "shift", action: .shift, label: .symbol(shiftSymbol),
            width: .units(1.5), style: .function,
            accessibilityLabel: shift == .locked ? "caps lock" : "shift"
        )]
        last += englishRows[2].map(key)
        last.append(deleteKey(width: 1.5))
        rows.append(KeyboardRow(keys: last, gridUnits: 10))
        return rows
    }

    static func symbolPageRows(_ language: KeyboardLanguage) -> [KeyboardRow] {
        func key(_ symbol: String) -> KeySpec {
            if language == .arabic, let arabic = arabicSymbolSubstitutes[symbol] {
                return characterKey(arabic, alternates: [arabic, symbol])
            }
            return characterKey(symbol, alternates: symbolAlternates[symbol] ?? [])
        }
        var rows = symbolRows.prefix(2).map { KeyboardRow(keys: $0.map(key), gridUnits: 10) }
        var last = symbolRows[2].map(key)
        last.append(deleteKey(width: 1))
        rows.append(KeyboardRow(keys: last, gridUnits: 10))
        return rows
    }

    static func bottomRow(_ ctx: LayoutContext) -> KeyboardRow {
        // UX spec §3–4: 🌐 | #+= | AR/EN | space | ↵
        var keys: [KeySpec] = []
        if ctx.needsGlobe {
            keys.append(KeySpec(id: "globe", action: .globe, label: .symbol("globe"),
                                width: .units(1.1), style: .function, accessibilityLabel: "next keyboard"))
        }
        let pageKey: KeySpec
        switch ctx.page {
        case .letters:
            pageKey = KeySpec(id: "page", action: .page(.symbols), label: .text("#+="),
                              width: .units(1.25), style: .function, accessibilityLabel: "symbols")
        case .symbols:
            pageKey = KeySpec(id: "page", action: .page(.letters),
                              label: .text(ctx.language == .arabic ? "أبج" : "ABC"),
                              width: .units(1.25), style: .function, accessibilityLabel: "letters")
        }
        keys.append(pageKey)
        keys.append(KeySpec(
            id: "lang", action: .languageToggle, label: .text(ctx.language.toggleLabel),
            width: .units(1.1), style: .function,
            accessibilityLabel: ctx.language == .arabic ? "switch to English" : "switch to Arabic"
        ))

        switch ctx.field {
        case .email:
            keys.append(characterKey("@", width: 1))
        case .url:
            keys.append(characterKey("/", width: 1))
        default:
            break
        }

        keys.append(KeySpec(id: "space", action: .space, label: .text(ctx.language.displayName),
                            width: .flexible, style: .character, accessibilityLabel: "space"))

        switch ctx.field {
        case .email:
            keys.append(characterKey(".", width: 1))
        case .url:
            keys.append(characterKey(".", width: 1))
            keys.append(KeySpec(id: ".com", action: .text(".com"), label: .text(".com"),
                                width: .units(1.3), style: .function, alternates: [".com", ".net", ".org", ".sa", ".io"]))
        default:
            keys.append(punctuationKey(ctx.language))
        }

        let returnLabel: KeyLabel = ctx.returnKind.label(for: ctx.language).map(KeyLabel.text) ?? .symbol("return")
        keys.append(KeySpec(
            id: "return", action: .returnKey, label: returnLabel, width: .units(1.8),
            style: ctx.returnKind.isPrimaryAction ? .primary : .function, accessibilityLabel: "return"
        ))
        return KeyboardRow(keys: keys, gridUnits: 10)
    }

    /// PT-02 candidate: ، / . stay in the letter layout with ؟ and friends on long-press.
    static func punctuationKey(_ language: KeyboardLanguage) -> KeySpec {
        switch language {
        case .arabic:
            return characterKey("،", width: 1, alternates: ["،", "؟", ".", "!", "؛", ":"])
        case .english:
            return characterKey(".", width: 1, alternates: [".", ",", "?", "!", "'", ":"])
        }
    }

    /// Number and decimal fields get a phone-style pad. iOS keeps phonePad fields on the
    /// system keyboard, so those never reach us (PRD §7).
    static func numberPadRows(_ ctx: LayoutContext) -> [KeyboardRow] {
        let digitRows = [["1", "2", "3"], ["4", "5", "6"], ["7", "8", "9"]]
        var rows = digitRows.map { r in KeyboardRow(keys: r.map { characterKey($0, alternates: [$0, arabicIndicDigits[$0]!]) }, gridUnits: 3) }
        var last: [KeySpec] = []
        if ctx.field == .decimal {
            last.append(characterKey(".", alternates: [".", ",", "٫"]))
        } else if ctx.needsGlobe {
            last.append(KeySpec(id: "globe", action: .globe, label: .symbol("globe"), style: .function,
                                accessibilityLabel: "next keyboard"))
        } else {
            last.append(KeySpec(id: "blank", action: .text(""), label: .text(""), style: .function))
        }
        last.append(characterKey("0", alternates: ["0", "٠"]))
        last.append(deleteKey(width: 1))
        rows.append(KeyboardRow(keys: last, gridUnits: 3))
        return rows
    }

    // MARK: Helpers

    static func characterKey(_ c: String, width: Double = 1, alternates: [String] = []) -> KeySpec {
        KeySpec(id: c, action: .character(c), label: .text(c), width: .units(width), alternates: alternates)
    }

    static func deleteKey(width: Double) -> KeySpec {
        KeySpec(id: "delete", action: .delete, label: .symbol("delete.left"),
                width: .units(width), style: .function, accessibilityLabel: "delete")
    }
}
