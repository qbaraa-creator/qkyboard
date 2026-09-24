import Foundation
import KeyboardCore

enum UtilityTab: String {
    case clipboard, snippets
}

/// Settings stored in the extension's own container. This works with Full Access OFF;
/// sharing them with the app through an App Group is TS-03.
struct ExtensionSettings {
    private let defaults = UserDefaults.standard

    private enum Key {
        static let lastLanguage = "lastLanguage"
        static let lastUtilityTab = "lastUtilityTab"
        static let haptics = "hapticsEnabled"
        static let keyPreview = "keyPreviewEnabled"
        static let doubleSpacePeriod = "doubleSpacePeriod"
        static let doubleSpacePeriodArabic = "doubleSpacePeriodArabic"
    }

    var lastLanguage: KeyboardLanguage {
        get { defaults.string(forKey: Key.lastLanguage).flatMap(KeyboardLanguage.init(rawValue:)) ?? .arabic }
        nonmutating set { defaults.set(newValue.rawValue, forKey: Key.lastLanguage) }
    }

    /// UX spec §8: ⌘ reopens the last tab; the first use opens Clipboard.
    var lastUtilityTab: UtilityTab {
        get { defaults.string(forKey: Key.lastUtilityTab).flatMap(UtilityTab.init(rawValue:)) ?? .clipboard }
        nonmutating set { defaults.set(newValue.rawValue, forKey: Key.lastUtilityTab) }
    }

    var hapticsEnabled: Bool {
        get { bool(Key.haptics, default: true) }
        nonmutating set { defaults.set(newValue, forKey: Key.haptics) }
    }

    /// PT-03: popup preview vs. haptic only.
    var keyPreviewEnabled: Bool {
        get { bool(Key.keyPreview, default: true) }
        nonmutating set { defaults.set(newValue, forKey: Key.keyPreview) }
    }

    var doubleSpacePeriod: Bool {
        get { bool(Key.doubleSpacePeriod, default: true) }
        nonmutating set { defaults.set(newValue, forKey: Key.doubleSpacePeriod) }
    }

    var doubleSpacePeriodArabic: Bool {
        get { bool(Key.doubleSpacePeriodArabic, default: false) }
        nonmutating set { defaults.set(newValue, forKey: Key.doubleSpacePeriodArabic) }
    }

    private func bool(_ key: String, default value: Bool) -> Bool {
        defaults.object(forKey: key) as? Bool ?? value
    }
}
