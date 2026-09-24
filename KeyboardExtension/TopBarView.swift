import UIKit

/// Prediction bar: `⌘ | Candidate 1 | Candidate 2 | Candidate 3` (UX spec §6), with no
/// other icons around it.
final class TopBarView: UIView {
    var onUtilityTap: (() -> Void)?
    var onUtilityLongPress: (() -> Void)?
    var onCandidateTap: ((String) -> Void)?

    private let utilityButton = UIButton(type: .system)
    private var candidateButtons: [UIButton] = []
    private var dividers: [UIView] = []
    private var candidates: [String] = []
    private let utilityWidth: CGFloat = 44

    override init(frame: CGRect) {
        super.init(frame: frame)

        utilityButton.setImage(
            UIImage(systemName: "command", withConfiguration: UIImage.SymbolConfiguration(pointSize: 17)),
            for: .normal
        )
        utilityButton.tintColor = KeyboardTheme.label
        utilityButton.accessibilityLabel = "Clipboard and snippets"
        utilityButton.addAction(UIAction { [weak self] _ in self?.onUtilityTap?() }, for: .touchUpInside)
        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(utilityLongPressed(_:)))
        utilityButton.addGestureRecognizer(longPress)
        addSubview(utilityButton)

        for i in 0..<3 {
            let button = UIButton(type: .custom)
            button.titleLabel?.font = .systemFont(ofSize: 16)
            button.titleLabel?.lineBreakMode = .byTruncatingMiddle
            button.setTitleColor(KeyboardTheme.label, for: .normal)
            button.setTitleColor(KeyboardTheme.secondaryLabel, for: .highlighted)
            button.addAction(UIAction { [weak self] _ in
                guard let self, i < self.candidates.count else { return }
                self.onCandidateTap?(self.candidates[i])
            }, for: .touchUpInside)
            addSubview(button)
            candidateButtons.append(button)

            let divider = UIView()
            divider.backgroundColor = KeyboardTheme.secondaryLabel.withAlphaComponent(0.3)
            addSubview(divider)
            dividers.append(divider)
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    /// `typed` is the exact word the user typed; it is shown in quotes so accepting it
    /// never looks like a correction (UX spec §7, §30 State C).
    func setCandidates(_ items: [String], typed: String?) {
        let items = Array(items.prefix(3))
        guard items != candidates else { return }
        candidates = items
        for (i, button) in candidateButtons.enumerated() {
            if i < items.count {
                let text = items[i]
                button.setTitle(text == typed ? "“\(text)”" : text, for: .normal)
                button.accessibilityLabel = text
                button.isHidden = false
            } else {
                button.setTitle(nil, for: .normal)
                button.isHidden = true
            }
        }
    }

    @objc private func utilityLongPressed(_ gesture: UILongPressGestureRecognizer) {
        if gesture.state == .began { onUtilityLongPress?() }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        utilityButton.frame = CGRect(x: 0, y: 0, width: utilityWidth, height: bounds.height)
        let slot = (bounds.width - utilityWidth) / 3
        for (i, button) in candidateButtons.enumerated() {
            let x = utilityWidth + slot * CGFloat(i)
            button.frame = CGRect(x: x, y: 0, width: slot, height: bounds.height).insetBy(dx: 4, dy: 0)
            dividers[i].frame = CGRect(x: x - 0.5, y: bounds.height * 0.25, width: 1, height: bounds.height * 0.5)
        }
    }
}
