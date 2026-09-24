import UIKit

/// Productivity Mode (UX spec §2B, §9–12): temporarily replaces the keyboard with
/// Clipboard | Snippets. One tap on an item inserts it and returns to typing.
///
/// Prototype scope (§50): no clipboard storage yet, so Clipboard shows its empty state
/// and Snippets shows fixed sample items to test the insert-and-return flow.
final class ProductivityView: UIView, UITableViewDataSource, UITableViewDelegate {
    var onClose: (() -> Void)?
    var onInsert: ((String) -> Void)?
    var onTabChange: ((UtilityTab) -> Void)?

    private struct Section {
        let title: String
        let items: [String]
    }

    private static let sampleSnippets = [
        Section(title: "PINNED", items: ["Atlas Roastery", "متى سيتم التنفيذ؟", "Please send me the details."]),
        Section(title: "RECENT", items: ["حسب الاتفاق السابق.", "I'll check and get back to you.",
                                         "الرجاء إرسال الصور بعد الانتهاء."]),
    ]

    private let backButton = UIButton(type: .system)
    private let tabs = UISegmentedControl(items: ["Clipboard", "Snippets"])
    private let table = UITableView(frame: .zero, style: .plain)
    private let emptyLabel = UILabel()
    private var sections: [Section] = []

    private(set) var tab: UtilityTab = .clipboard

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = KeyboardTheme.background

        var config = UIButton.Configuration.plain()
        config.title = "Keyboard"
        config.image = UIImage(systemName: "chevron.left", withConfiguration: UIImage.SymbolConfiguration(pointSize: 13, weight: .semibold))
        config.imagePadding = 4
        config.baseForegroundColor = KeyboardTheme.label
        backButton.configuration = config
        backButton.accessibilityLabel = "Back to keyboard"
        backButton.addAction(UIAction { [weak self] _ in self?.onClose?() }, for: .touchUpInside)
        addSubview(backButton)

        tabs.addAction(UIAction { [weak self] _ in
            guard let self else { return }
            let tab: UtilityTab = self.tabs.selectedSegmentIndex == 0 ? .clipboard : .snippets
            self.show(tab)
            self.onTabChange?(tab)
        }, for: .valueChanged)
        addSubview(tabs)

        table.dataSource = self
        table.delegate = self
        table.backgroundColor = .clear
        table.rowHeight = 44
        table.sectionHeaderTopPadding = 0
        table.register(UITableViewCell.self, forCellReuseIdentifier: "item")
        addSubview(table)

        emptyLabel.numberOfLines = 0
        emptyLabel.textAlignment = .center
        emptyLabel.font = .systemFont(ofSize: 15)
        emptyLabel.textColor = KeyboardTheme.secondaryLabel
        addSubview(emptyLabel)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    func show(_ tab: UtilityTab) {
        self.tab = tab
        tabs.selectedSegmentIndex = tab == .clipboard ? 0 : 1
        switch tab {
        case .clipboard:
            sections = []
            // §42 empty state.
            emptyLabel.text = "No saved clipboard items yet.\nCopy something, then add it to your clipboard."
        case .snippets:
            sections = Self.sampleSnippets
            emptyLabel.text = "No snippets yet.\nCreate reusable text from the Personal Keyboard app."
        }
        emptyLabel.isHidden = !sections.isEmpty
        table.isHidden = sections.isEmpty
        table.reloadData()
        table.setContentOffset(.zero, animated: false)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let headerHeight: CGFloat = 44
        backButton.frame = CGRect(x: 4, y: 0, width: 110, height: headerHeight)
        let tabsWidth = min(220, bounds.width - 130)
        tabs.frame = CGRect(x: bounds.width - tabsWidth - 8, y: 7, width: tabsWidth, height: 30)
        let content = CGRect(x: 0, y: headerHeight, width: bounds.width, height: bounds.height - headerHeight)
        table.frame = content
        emptyLabel.frame = content.insetBy(dx: 24, dy: 16)
    }

    // MARK: Table

    func numberOfSections(in tableView: UITableView) -> Int { sections.count }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        sections[section].items.count
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        sections[section].title
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "item", for: indexPath)
        var content = cell.defaultContentConfiguration()
        content.text = sections[indexPath.section].items[indexPath.row]
        content.textProperties.numberOfLines = 1
        cell.contentConfiguration = content
        cell.backgroundColor = .clear
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: false)
        onInsert?(sections[indexPath.section].items[indexPath.row])
    }
}
