import KeyboardCore
import os
import UIKit

/// Input view that opts into the system keyboard click sound.
final class KeyboardInputView: UIInputView, UIInputViewAudioFeedback {
    var enableInputClicksWhenVisible: Bool { true }
}

final class KeyboardViewController: UIInputViewController {
    private let engine = KeyboardEngine()
    private let settings = ExtensionSettings()
    private let topBar = TopBarView()
    private let keyboardView = KeyboardView()
    private let predictor = MockPredictor()
    private lazy var productivityView = ProductivityView()
    private var optionsView: PrototypeOptionsView?
    private var heightConstraint: NSLayoutConstraint?
    private lazy var haptics = UIImpactFeedbackGenerator(style: .light)

    private var latency = LatencyTracker()
    private let log = Logger(subsystem: "com.baraaqassam.bkeyboard.keyboard", category: "typing")
    private let signposter = OSSignposter(subsystem: "com.baraaqassam.bkeyboard.keyboard", category: .pointsOfInterest)

    private var field: FieldKind = .text
    private var returnKind: ReturnKind = .default
    private var lastNeedsGlobe: Bool?
    private var lastLayoutContext: LayoutContext?

    private let topBarHeight: CGFloat = 40

    override func loadView() {
        let inputView = KeyboardInputView(frame: .zero, inputViewStyle: .keyboard)
        inputView.allowsSelfSizing = true
        view = inputView
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        engine.setLanguage(settings.lastLanguage)
        applySettings()
        view.backgroundColor = KeyboardTheme.background

        topBar.translatesAutoresizingMaskIntoConstraints = false
        keyboardView.translatesAutoresizingMaskIntoConstraints = false
        keyboardView.delegate = self
        keyboardView.configureGlobeButton = { [unowned self] button in
            button.addTarget(self, action: #selector(UIInputViewController.handleInputModeList(from:with:)), for: .allTouchEvents)
        }
        // Keys draw their popups above the top bar, so the bar goes underneath.
        view.addSubview(topBar)
        view.addSubview(keyboardView)
        NSLayoutConstraint.activate([
            topBar.topAnchor.constraint(equalTo: view.topAnchor),
            topBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            topBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            topBar.heightAnchor.constraint(equalToConstant: topBarHeight),
            keyboardView.topAnchor.constraint(equalTo: topBar.bottomAnchor),
            keyboardView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            keyboardView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            keyboardView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        let height = view.heightAnchor.constraint(equalToConstant: preferredHeight())
        height.priority = UILayoutPriority(999)
        height.isActive = true
        heightConstraint = height

        topBar.onCandidateTap = { [unowned self] candidate in acceptCandidate(candidate) }
        topBar.onUtilityTap = { [unowned self] in showProductivity() }
        #if DEBUG
        topBar.onUtilityLongPress = { [unowned self] in showPrototypeOptions() }
        #endif

        registerForTraitChanges([UITraitVerticalSizeClass.self]) { (self: Self, _: UITraitCollection) in
            self.heightConstraint?.constant = self.preferredHeight()
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        readDocumentTraits()
        refreshAutoShift()
        render()
        refreshCandidates()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // The system edge gesture otherwise delays touches on the bottom row.
        view.window?.gestureRecognizers?.forEach { $0.delaysTouchesBegan = false }
        if settings.hapticsEnabled { haptics.prepare() }
    }

    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        heightConstraint?.constant = preferredHeight()
        if lastNeedsGlobe != needsInputModeSwitchKey { render() }
    }

    override func textDidChange(_ textInput: UITextInput?) {
        super.textDidChange(textInput)
        readDocumentTraits()
        refreshAutoShift()
        render()
        refreshCandidates()
    }

    private func preferredHeight() -> CGFloat {
        let landscape = traitCollection.verticalSizeClass == .compact
        let rowHeight: CGFloat = landscape ? 38 : 50
        let rowCount: CGFloat = (field == .number || field == .decimal) ? 4 : 5
        return topBarHeight + rowHeight * rowCount + 4
    }

    // MARK: Document

    private func readDocumentTraits() {
        let proxy = textDocumentProxy
        let newField: FieldKind
        switch proxy.keyboardType ?? .default {
        case .emailAddress: newField = .email
        case .URL: newField = .url
        case .webSearch: newField = .webSearch
        case .numberPad, .asciiCapableNumberPad: newField = .number
        case .decimalPad: newField = .decimal
        default: newField = .text
        }
        if newField != field {
            field = newField
            heightConstraint?.constant = preferredHeight()
        }

        switch proxy.returnKeyType ?? .default {
        case .go: returnKind = .go
        case .google, .yahoo, .search: returnKind = .search
        case .send: returnKind = .send
        case .done: returnKind = .done
        case .next: returnKind = .next
        case .join: returnKind = .join
        case .route: returnKind = .route
        case .continue: returnKind = .continue
        default: returnKind = field == .webSearch ? .search : .default
        }

        let appearance = proxy.keyboardAppearance ?? .default
        view.overrideUserInterfaceStyle = appearance == .dark ? .dark : .unspecified
    }

    private func textContext() -> TextContext {
        let autocap: AutocapMode
        switch textDocumentProxy.autocapitalizationType ?? .sentences {
        case .none: autocap = .none
        case .words: autocap = .words
        case .allCharacters: autocap = .allCharacters
        default: autocap = .sentences
        }
        let noAutocapFields: Set<FieldKind> = [.email, .url]
        return TextContext(
            before: textDocumentProxy.documentContextBeforeInput,
            autocap: noAutocapFields.contains(field) ? .none : autocap
        )
    }

    private func refreshAutoShift() {
        engine.updateAutoShift(context: textContext())
    }

    private func render() {
        lastNeedsGlobe = needsInputModeSwitchKey
        let ctx = engine.layoutContext(field: field, returnKind: returnKind, needsGlobe: needsInputModeSwitchKey)
        guard ctx != lastLayoutContext else { return }
        lastLayoutContext = ctx
        keyboardView.isRightToLeft = engine.language.isRightToLeft
        keyboardView.setRows(KeyboardLayout.rows(for: ctx))
    }

    private func applySettings() {
        engine.settings.doubleSpacePeriod = settings.doubleSpacePeriod
        engine.settings.doubleSpacePeriodArabic = settings.doubleSpacePeriodArabic
        keyboardView.showsKeyPreview = settings.keyPreviewEnabled
    }

    private func perform(_ ops: [TextOperation]) {
        let proxy = textDocumentProxy
        for op in ops {
            switch op {
            case .insert(let text): proxy.insertText(text)
            case .deleteBackward(let count): for _ in 0..<count { proxy.deleteBackward() }
            }
        }
    }

    // MARK: Prediction bar

    private func refreshCandidates() {
        // Mock predictions are microseconds; the real engine must keep this off the
        // keystroke path and never show a spinner (UX spec §44).
        let before = textDocumentProxy.documentContextBeforeInput
        let typed = TextEditing.currentToken(before: before)
        topBar.setCandidates(predictor.candidates(before: before), typed: typed.isEmpty ? nil : typed)
    }

    private func acceptCandidate(_ candidate: String) {
        perform(engine.acceptCandidate(candidate, context: textContext()))
        refreshAutoShift()
        render()
        refreshCandidates()
    }

    // MARK: Productivity mode

    private func showProductivity() {
        if productivityView.superview == nil {
            productivityView.translatesAutoresizingMaskIntoConstraints = false
            productivityView.onClose = { [unowned self] in hideProductivity() }
            productivityView.onTabChange = { [unowned self] tab in settings.lastUtilityTab = tab }
            productivityView.onInsert = { [unowned self] text in
                textDocumentProxy.insertText(text)
                hideProductivity()
            }
            pinToEdges(productivityView)
        }
        keyboardView.cancelAllTouches()
        productivityView.show(settings.lastUtilityTab)
        productivityView.isHidden = false
    }

    /// Language and text are untouched on the way back (UX spec §11).
    private func hideProductivity() {
        productivityView.isHidden = true
        refreshAutoShift()
        render()
        refreshCandidates()
    }

    private func pinToEdges(_ subview: UIView) {
        subview.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(subview)
        NSLayoutConstraint.activate([
            subview.topAnchor.constraint(equalTo: view.topAnchor),
            subview.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            subview.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            subview.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }

    // MARK: Prototype options (debug)

    private func showPrototypeOptions() {
        let options = PrototypeOptionsView(settings: settings)
        options.onChange = { [unowned self] in applySettings() }
        options.onClose = { [unowned self, unowned options] in
            options.removeFromSuperview()
            optionsView = nil
        }
        options.setStats(latencySummary())
        pinToEdges(options)
        optionsView = options
    }

    private func latencySummary() -> String {
        let access = hasFullAccess ? "Full Access ON" : "Full Access OFF"
        guard let p50 = latency.percentile(50), let p95 = latency.percentile(95) else {
            return "No keystrokes measured yet · \(access)"
        }
        return String(format: "Key → insert  p50 %.1f ms · p95 %.1f ms · n %ld\n%@",
                      p50, p95, latency.totalCount, access)
    }
}

extension KeyboardViewController: KeyboardViewDelegate {
    func keyboardViewDidTouchDownKey(_ view: KeyboardView) {
        UIDevice.current.playInputClick()
        if settings.hapticsEnabled, hasFullAccess { haptics.impactOccurred() }
    }

    func keyboardView(_ view: KeyboardView, perform action: KeyAction, eventTime: TimeInterval?) {
        let signpostID = signposter.makeSignpostID()
        let interval = signposter.beginInterval("key", id: signpostID)

        let languageBefore = engine.language
        let now = ProcessInfo.processInfo.systemUptime
        let ops = engine.handle(action, context: textContext(), time: eventTime ?? now)
        perform(ops)

        // Timer-driven repeats have no touch to measure from.
        if !ops.isEmpty, let eventTime {
            let ms = (ProcessInfo.processInfo.systemUptime - eventTime) * 1000
            latency.record(milliseconds: ms)
            if ms > 50 { log.notice("slow key: \(ms, format: .fixed(precision: 1)) ms") }
        }
        signposter.endInterval("key", interval)

        if engine.language != languageBefore { settings.lastLanguage = engine.language }
        if !ops.isEmpty { refreshAutoShift() }
        render()
        if !ops.isEmpty { refreshCandidates() }
    }
}
