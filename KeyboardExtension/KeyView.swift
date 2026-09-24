import KeyboardCore
import UIKit

/// Renders one key. Touches are handled centrally by `KeyboardView`, so this view is
/// not interactive itself.
final class KeyView: UIView {
    private(set) var spec: KeySpec
    private let background = UIView()
    private let titleLabel = UILabel()
    private let imageView = UIImageView()

    var isPressed = false {
        didSet { if oldValue != isPressed { applyColors() } }
    }

    init(spec: KeySpec) {
        self.spec = spec
        super.init(frame: .zero)
        isUserInteractionEnabled = false

        background.layer.cornerRadius = KeyboardTheme.keyCornerRadius
        background.layer.cornerCurve = .continuous
        background.layer.shadowOpacity = 1
        background.layer.shadowRadius = 0
        background.layer.shadowOffset = CGSize(width: 0, height: 1)
        addSubview(background)

        titleLabel.textAlignment = .center
        titleLabel.adjustsFontSizeToFitWidth = true
        titleLabel.minimumScaleFactor = 0.5
        titleLabel.baselineAdjustment = .alignCenters
        addSubview(titleLabel)

        imageView.contentMode = .center
        imageView.tintColor = KeyboardTheme.label
        addSubview(imageView)

        // CGColor shadows don't follow trait changes on their own.
        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (view: KeyView, _: UITraitCollection) in
            view.applyColors()
        }

        isAccessibilityElement = true
        accessibilityTraits = .keyboardKey
        update(spec: spec)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    func update(spec: KeySpec) {
        self.spec = spec
        accessibilityLabel = spec.accessibilityLabel
        switch spec.label {
        case .text(let text):
            titleLabel.text = text
            titleLabel.isHidden = false
            imageView.isHidden = true
        case .symbol(let name):
            imageView.image = UIImage(
                systemName: name,
                withConfiguration: UIImage.SymbolConfiguration(pointSize: 18, weight: .regular)
            )
            imageView.isHidden = false
            titleLabel.isHidden = true
        }
        titleLabel.font = font(for: spec)
        titleLabel.textColor = spec.action == .space ? KeyboardTheme.secondaryLabel
            : spec.style == .primary ? .white : KeyboardTheme.label
        imageView.tintColor = spec.style == .primary ? .white : KeyboardTheme.label
        applyColors()
    }

    private func font(for spec: KeySpec) -> UIFont {
        if spec.action == .space { return .systemFont(ofSize: 15) }
        switch spec.style {
        case .character:
            if case .character = spec.action { return .systemFont(ofSize: 23, weight: .regular) }
            return .systemFont(ofSize: 16)
        case .function, .primary:
            return .systemFont(ofSize: 16)
        }
    }

    private func applyColors() {
        let color: UIColor
        switch spec.style {
        case .character: color = isPressed ? KeyboardTheme.characterKeyPressed : KeyboardTheme.characterKey
        case .function: color = isPressed ? KeyboardTheme.functionKeyPressed : KeyboardTheme.functionKey
        case .primary: color = isPressed ? KeyboardTheme.primaryKeyPressed : KeyboardTheme.primaryKey
        }
        background.backgroundColor = color
        background.layer.shadowColor = KeyboardTheme.keyShadow.resolvedColor(with: traitCollection).cgColor
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let inset = bounds.insetBy(dx: KeyboardTheme.keyGapX / 2, dy: KeyboardTheme.keyGapY / 2)
        background.frame = inset
        background.layer.shadowPath = UIBezierPath(
            roundedRect: background.bounds, cornerRadius: KeyboardTheme.keyCornerRadius
        ).cgPath
        titleLabel.frame = inset.insetBy(dx: 2, dy: 0)
        imageView.frame = inset
    }

    /// The visible key face, in this view's coordinates.
    var faceFrame: CGRect { background.frame }
}
