import UIKit

/// Colors approximating the system keyboard, resolved per light/dark trait.
enum KeyboardTheme {
    static let background = UIColor { $0.userInterfaceStyle == .dark
        ? UIColor(white: 0.17, alpha: 1)
        : UIColor(red: 0.82, green: 0.83, blue: 0.85, alpha: 1) }

    static let characterKey = UIColor { $0.userInterfaceStyle == .dark
        ? UIColor(white: 0.42, alpha: 1)
        : .white }

    static let functionKey = UIColor { $0.userInterfaceStyle == .dark
        ? UIColor(white: 0.27, alpha: 1)
        : UIColor(red: 0.67, green: 0.69, blue: 0.73, alpha: 1) }

    static let characterKeyPressed = functionKey
    static let functionKeyPressed = characterKey

    static let primaryKey = UIColor.systemBlue
    static let primaryKeyPressed = UIColor.systemBlue.withAlphaComponent(0.7)

    static let keyShadow = UIColor { $0.userInterfaceStyle == .dark
        ? UIColor.black.withAlphaComponent(0.6)
        : UIColor(red: 0.53, green: 0.54, blue: 0.56, alpha: 1) }

    static let label = UIColor.label
    static let secondaryLabel = UIColor.secondaryLabel
    static let selection = UIColor.systemBlue

    static let keyCornerRadius: CGFloat = 5
    static let keyGapX: CGFloat = 6
    static let keyGapY: CGFloat = 10
    static let sideInset: CGFloat = 3
}
