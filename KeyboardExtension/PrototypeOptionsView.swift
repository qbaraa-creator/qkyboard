import UIKit

/// Debug-only panel (long-press ⌘) for toggling the open prototype decisions on the
/// device, and for reading the live latency numbers. Not part of the product UI.
final class PrototypeOptionsView: UIView {
    var onClose: (() -> Void)?
    var onChange: (() -> Void)?

    private let settings: ExtensionSettings
    private let stack = UIStackView()
    private let statsLabel = UILabel()

    init(settings: ExtensionSettings) {
        self.settings = settings
        super.init(frame: .zero)
        backgroundColor = KeyboardTheme.background

        stack.axis = .vertical
        stack.spacing = 6
        addSubview(stack)

        let header = UIStackView()
        let title = UILabel()
        title.text = "Prototype options"
        title.font = .boldSystemFont(ofSize: 15)
        let done = UIButton(type: .system)
        done.setTitle("Done", for: .normal)
        done.addAction(UIAction { [weak self] _ in self?.onClose?() }, for: .touchUpInside)
        header.addArrangedSubview(title)
        header.addArrangedSubview(done)
        stack.addArrangedSubview(header)

        addToggle("PT-03 · Key preview popup", isOn: settings.keyPreviewEnabled) { settings.keyPreviewEnabled = $0 }
        addToggle("Haptics (needs Full Access)", isOn: settings.hapticsEnabled) { settings.hapticsEnabled = $0 }
        addToggle("Double space → . (English)", isOn: settings.doubleSpacePeriod) { settings.doubleSpacePeriod = $0 }
        addToggle("Double space → . (Arabic)", isOn: settings.doubleSpacePeriodArabic) { settings.doubleSpacePeriodArabic = $0 }

        statsLabel.font = .monospacedDigitSystemFont(ofSize: 12, weight: .regular)
        statsLabel.textColor = KeyboardTheme.secondaryLabel
        statsLabel.numberOfLines = 2
        stack.addArrangedSubview(statsLabel)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    func setStats(_ text: String) {
        statsLabel.text = text
    }

    private func addToggle(_ title: String, isOn: Bool, set: @escaping (Bool) -> Void) {
        let row = UIStackView()
        row.alignment = .center
        let label = UILabel()
        label.text = title
        label.font = .systemFont(ofSize: 14)
        label.adjustsFontSizeToFitWidth = true
        let toggle = UISwitch()
        toggle.isOn = isOn
        toggle.addAction(UIAction { [weak self, weak toggle] _ in
            guard let toggle else { return }
            set(toggle.isOn)
            self?.onChange?()
        }, for: .valueChanged)
        row.addArrangedSubview(label)
        row.addArrangedSubview(toggle)
        stack.addArrangedSubview(row)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        stack.frame = bounds.insetBy(dx: 14, dy: 8)
    }
}
