import UIKit

/// Magnified preview above a pressed key, which expands into a row of long-press
/// alternates.
final class KeyPopupView: UIView {
    private var labels: [UILabel] = []
    private(set) var options: [String] = []
    private(set) var selectedIndex = 0
    private let cellWidth: CGFloat
    private let cellHeight: CGFloat = 48

    init(keyFaceWidth: CGFloat) {
        cellWidth = max(keyFaceWidth + 8, 38)
        super.init(frame: .zero)
        isUserInteractionEnabled = false
        backgroundColor = KeyboardTheme.characterKey
        layer.cornerRadius = 8
        layer.cornerCurve = .continuous
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.3
        layer.shadowRadius = 3
        layer.shadowOffset = CGSize(width: 0, height: 1)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    /// Positions the popup centered above `anchor` (a key face), kept inside `bounds`.
    func showPreview(_ text: String, above anchor: CGRect, within container: CGRect) {
        configure(options: [text], selected: 0, fontSize: 32)
        place(above: anchor, within: container, width: cellWidth, alignLeadingTo: nil)
    }

    func showAlternates(_ options: [String], above anchor: CGRect, within container: CGRect, rightToLeft: Bool) {
        let ordered = rightToLeft ? Array(options.reversed()) : options
        configure(options: ordered, selected: rightToLeft ? ordered.count - 1 : 0, fontSize: 24)
        place(above: anchor, within: container, width: cellWidth * CGFloat(ordered.count),
              alignLeadingTo: rightToLeft ? anchor.maxX + 4 : anchor.minX - 4, fromTrailing: rightToLeft)
    }

    var selectedOption: String? {
        options.indices.contains(selectedIndex) ? options[selectedIndex] : nil
    }

    /// Updates the highlighted alternate from a touch x-position in the superview's space.
    func select(atX x: CGFloat) {
        guard options.count > 1 else { return }
        let local = x - frame.minX
        let index = min(max(Int(local / cellWidth), 0), options.count - 1)
        guard index != selectedIndex else { return }
        selectedIndex = index
        applySelection()
    }

    private func configure(options: [String], selected: Int, fontSize: CGFloat) {
        self.options = options
        selectedIndex = selected
        labels.forEach { $0.removeFromSuperview() }
        labels = options.map { text in
            let label = UILabel()
            label.text = text
            label.font = .systemFont(ofSize: fontSize)
            label.textAlignment = .center
            label.layer.cornerRadius = 6
            label.layer.cornerCurve = .continuous
            label.clipsToBounds = true
            addSubview(label)
            return label
        }
        applySelection()
    }

    private func applySelection() {
        let highlight = options.count > 1
        for (i, label) in labels.enumerated() {
            let selected = highlight && i == selectedIndex
            label.backgroundColor = selected ? KeyboardTheme.selection : .clear
            label.textColor = selected ? .white : KeyboardTheme.label
        }
    }

    private func place(above anchor: CGRect, within container: CGRect, width: CGFloat,
                       alignLeadingTo leading: CGFloat?, fromTrailing: Bool = false) {
        var x: CGFloat
        if let leading {
            x = fromTrailing ? leading - width : leading
        } else {
            x = anchor.midX - width / 2
        }
        x = min(max(x, container.minX + 2), container.maxX - width - 2)
        let y = anchor.minY - cellHeight - 6
        frame = CGRect(x: x, y: y, width: width, height: cellHeight)
        for (i, label) in labels.enumerated() {
            label.frame = CGRect(x: CGFloat(i) * cellWidth, y: 0, width: cellWidth, height: cellHeight)
                .insetBy(dx: 3, dy: 4)
        }
    }
}
