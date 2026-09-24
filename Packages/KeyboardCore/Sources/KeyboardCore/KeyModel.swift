import Foundation

/// The two layouts the keyboard ships with. A layout decides which characters the keys
/// produce; it does not restrict which language suggestions may come from (PRD §22).
public enum KeyboardLanguage: String, CaseIterable, Sendable {
    case arabic = "ar"
    case english = "en"

    public var toggled: KeyboardLanguage { self == .arabic ? .english : .arabic }

    public var isRightToLeft: Bool { self == .arabic }

    /// Shown on the space bar so the current state never relies on color alone (PRD §39).
    public var displayName: String { self == .arabic ? "العربية" : "English" }

    /// The AR ⇄ EN key names the layout it switches *to*.
    public var toggleLabel: String { self == .arabic ? "EN" : "AR" }
}

public enum KeyboardPage: Sendable, Hashable {
    case letters
    case symbols
}

public enum ShiftState: Sendable, Hashable {
    case off
    /// One-shot: applies to the next character, then turns off.
    case on
    case locked
}

/// What kind of text field the host app reports, reduced to what changes our layout.
public enum FieldKind: Sendable, Hashable {
    case text
    case email
    case url
    case webSearch
    case number
    case decimal
}

public enum ReturnKind: Sendable, Hashable {
    case `default`, go, search, send, done, next, join, route, `continue`

    public func label(for language: KeyboardLanguage) -> String? {
        let ar = language == .arabic
        switch self {
        case .default: return nil
        case .go: return ar ? "انتقال" : "Go"
        case .search: return ar ? "بحث" : "Search"
        case .send: return ar ? "إرسال" : "Send"
        case .done: return ar ? "تم" : "Done"
        case .next: return ar ? "التالي" : "Next"
        case .join: return ar ? "انضمام" : "Join"
        case .route: return ar ? "المسار" : "Route"
        case .continue: return ar ? "متابعة" : "Continue"
        }
    }

    /// iOS highlights the return key for actions that submit something.
    public var isPrimaryAction: Bool {
        switch self {
        case .go, .search, .send, .join, .route: return true
        default: return false
        }
    }
}

public enum AutocapMode: Sendable, Hashable {
    case none, words, sentences, allCharacters
}

public enum KeyAction: Sendable, Hashable {
    case character(String)
    /// Literal text that is never case-transformed, e.g. ".com".
    case text(String)
    case space
    case delete
    case deleteWord
    case returnKey
    case shift
    case languageToggle
    case globe
    case page(KeyboardPage)
}

public enum KeyLabel: Sendable, Hashable {
    case text(String)
    /// SF Symbol name.
    case symbol(String)
}

public enum KeyStyle: Sendable, Hashable {
    case character
    case function
    case primary
}

public enum KeyWidth: Sendable, Hashable {
    case units(Double)
    /// Takes whatever horizontal space the fixed keys leave in the row.
    case flexible
}

public struct KeySpec: Sendable, Hashable, Identifiable {
    public var id: String
    public var action: KeyAction
    public var label: KeyLabel
    public var width: KeyWidth
    public var style: KeyStyle
    /// Long-press alternatives. The first entry is the key's own output.
    public var alternates: [String]
    public var accessibilityLabel: String

    public init(
        id: String,
        action: KeyAction,
        label: KeyLabel,
        width: KeyWidth = .units(1),
        style: KeyStyle = .character,
        alternates: [String] = [],
        accessibilityLabel: String? = nil
    ) {
        self.id = id
        self.action = action
        self.label = label
        self.width = width
        self.style = style
        self.alternates = alternates
        if let accessibilityLabel {
            self.accessibilityLabel = accessibilityLabel
        } else if case .text(let t) = label {
            self.accessibilityLabel = t
        } else {
            self.accessibilityLabel = id
        }
    }

    /// Character keys show a magnified preview while pressed.
    public var showsPreview: Bool {
        if case .character = action { return true }
        return false
    }
}

public struct KeyboardRow: Sendable, Hashable {
    public var keys: [KeySpec]
    /// How many width units span the full row. Rows whose fixed keys add up to less
    /// than this, and that have no flexible key, are centered.
    public var gridUnits: Double

    public init(keys: [KeySpec], gridUnits: Double) {
        self.keys = keys
        self.gridUnits = gridUnits
    }

    /// Resolves each key's x-offset and width for a row of the given width.
    public func frames(totalWidth: Double) -> [(x: Double, width: Double)] {
        let unit = totalWidth / gridUnits
        var fixed = 0.0
        var flexibleCount = 0
        for key in keys {
            switch key.width {
            case .units(let u): fixed += u * unit
            case .flexible: flexibleCount += 1
            }
        }
        let flexibleWidth = flexibleCount > 0 ? max(0, (totalWidth - fixed) / Double(flexibleCount)) : 0
        var x = flexibleCount > 0 ? 0 : max(0, (totalWidth - fixed) / 2)
        var result: [(Double, Double)] = []
        result.reserveCapacity(keys.count)
        for key in keys {
            let w: Double
            switch key.width {
            case .units(let u): w = u * unit
            case .flexible: w = flexibleWidth
            }
            result.append((x, w))
            x += w
        }
        return result
    }
}

public enum TextOperation: Sendable, Equatable {
    case insert(String)
    case deleteBackward(Int)
}
