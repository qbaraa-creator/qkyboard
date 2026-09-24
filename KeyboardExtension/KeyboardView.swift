import KeyboardCore
import UIKit

protocol KeyboardViewDelegate: AnyObject {
    /// `eventTime` is the `UITouch.timestamp` that triggered the action, used for latency.
    /// It is nil for timer-driven actions such as delete repeat.
    func keyboardView(_ view: KeyboardView, perform action: KeyAction, eventTime: TimeInterval?)
    /// Fired on touch-down of any key, for haptics and click sound.
    func keyboardViewDidTouchDownKey(_ view: KeyboardView)
}

/// Lays out the key grid and owns all touch handling, so fast typing with overlapping
/// touches (rollover) and sliding between keys behave like the system keyboard.
final class KeyboardView: UIView {
    weak var delegate: KeyboardViewDelegate?
    /// Called whenever a globe button is created, so the controller can wire it to
    /// `handleInputModeList(from:with:)`.
    var configureGlobeButton: ((UIButton) -> Void)?
    var isRightToLeft = false
    /// PT-03: magnified popup on press, or haptic feedback only.
    var showsKeyPreview = true

    private var rows: [KeyboardRow] = []
    private var keyViews: [[KeyView]] = []
    private var globeButton: UIButton?

    private let deleteSchedule = DeleteRepeatSchedule()
    private let longPressDelay: TimeInterval = 0.4

    private final class TouchState {
        var row: Int
        var column: Int
        var popup: KeyPopupView?
        var showingAlternates = false
        var longPressTimer: Timer?
        var deleteTimer: Timer?
        var deleteTick = 0

        init(row: Int, column: Int) {
            self.row = row
            self.column = column
        }

        func invalidateTimers() {
            longPressTimer?.invalidate()
            longPressTimer = nil
            deleteTimer?.invalidate()
            deleteTimer = nil
        }
    }

    /// Keyed by touch identity; UITouch objects persist for the touch's lifetime.
    private var touches: [ObjectIdentifier: TouchState] = [:]
    /// Order in which character touches began, for rollover commits.
    private var pendingOrder: [ObjectIdentifier] = []

    override init(frame: CGRect) {
        super.init(frame: frame)
        isMultipleTouchEnabled = true
        clipsToBounds = false
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    // MARK: Layout

    func setRows(_ newRows: [KeyboardRow]) {
        guard newRows != rows else { return }
        let sameShape = newRows.count == rows.count
            && zip(newRows, rows).allSatisfy { $0.keys.map(\.id) == $1.keys.map(\.id) }
        rows = newRows
        if sameShape {
            for (r, row) in newRows.enumerated() {
                for (c, spec) in row.keys.enumerated() { keyViews[r][c].update(spec: spec) }
            }
        } else {
            cancelAllTouches()
            keyViews.flatMap { $0 }.forEach { $0.removeFromSuperview() }
            keyViews = newRows.map { row in
                row.keys.map { spec in
                    let view = KeyView(spec: spec)
                    addSubview(view)
                    return view
                }
            }
            rebuildGlobeButton()
        }
        setNeedsLayout()
    }

    private func rebuildGlobeButton() {
        globeButton?.removeFromSuperview()
        globeButton = nil
        guard let globeView = keyViews.joined().first(where: { $0.spec.action == .globe }) else { return }
        let button = UIButton(type: .custom)
        button.accessibilityLabel = globeView.spec.accessibilityLabel
        button.addAction(UIAction { [weak globeView] _ in globeView?.isPressed = true }, for: .touchDown)
        for event: UIControl.Event in [.touchUpInside, .touchUpOutside, .touchCancel, .touchDragExit] {
            button.addAction(UIAction { [weak globeView] _ in globeView?.isPressed = false }, for: event)
        }
        addSubview(button)
        globeButton = button
        configureGlobeButton?(button)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard !rows.isEmpty else { return }
        let width = bounds.width - KeyboardTheme.sideInset * 2
        let rowHeight = bounds.height / CGFloat(rows.count)
        for (r, row) in rows.enumerated() {
            let frames = row.frames(totalWidth: Double(width))
            for (c, f) in frames.enumerated() {
                keyViews[r][c].frame = CGRect(
                    x: KeyboardTheme.sideInset + CGFloat(f.x),
                    y: CGFloat(r) * rowHeight,
                    width: CGFloat(f.width),
                    height: rowHeight
                )
            }
        }
        if let globeButton, let globeView = keyViews.joined().first(where: { $0.spec.action == .globe }) {
            globeButton.frame = globeView.frame
        }
    }

    /// Nearest key to a point. Rows tile the full height and keys tile their row, so
    /// gaps between key faces still resolve to a key.
    private func keyPosition(at point: CGPoint) -> (row: Int, column: Int)? {
        guard !rows.isEmpty else { return nil }
        let rowHeight = bounds.height / CGFloat(rows.count)
        let r = min(max(Int(point.y / rowHeight), 0), rows.count - 1)
        let views = keyViews[r]
        guard !views.isEmpty else { return nil }
        var best = 0
        var bestDistance = CGFloat.greatestFiniteMagnitude
        for (c, view) in views.enumerated() {
            let f = view.frame
            let distance = point.x < f.minX ? f.minX - point.x : point.x > f.maxX ? point.x - f.maxX : 0
            if distance < bestDistance {
                bestDistance = distance
                best = c
                if distance == 0 { break }
            }
        }
        return (r, best)
    }

    private func spec(_ state: TouchState) -> KeySpec { keyViews[state.row][state.column].spec }
    private func view(_ state: TouchState) -> KeyView { keyViews[state.row][state.column] }

    // MARK: Touches

    override func touchesBegan(_ newTouches: Set<UITouch>, with event: UIEvent?) {
        for touch in newTouches {
            guard let pos = keyPosition(at: touch.location(in: self)) else { continue }
            let state = TouchState(row: pos.row, column: pos.column)
            let key = spec(state)

            // Rollover: a new key press commits any character still held down.
            if case .character = key.action { commitPendingCharacters(at: touch.timestamp) }

            let id = ObjectIdentifier(touch)
            touches[id] = state
            view(state).isPressed = true
            delegate?.keyboardViewDidTouchDownKey(self)

            switch key.action {
            case .delete:
                delegate?.keyboardView(self, perform: .delete, eventTime: touch.timestamp)
                scheduleDeleteRepeat(state, delay: deleteSchedule.initialDelay)
            case .shift:
                // Shift reacts on touch-down so a quick double tap reliably locks caps.
                delegate?.keyboardView(self, perform: .shift, eventTime: touch.timestamp)
            case .character:
                pendingOrder.append(id)
                showPreview(state)
                scheduleLongPress(state)
            default:
                if key.alternates.count > 1 { scheduleLongPress(state) }
            }
        }
    }

    override func touchesMoved(_ movedTouches: Set<UITouch>, with event: UIEvent?) {
        for touch in movedTouches {
            guard let state = touches[ObjectIdentifier(touch)] else { continue }
            let point = touch.location(in: self)
            if state.showingAlternates {
                state.popup?.select(atX: point.x)
                continue
            }
            guard case .character = spec(state).action,
                  let pos = keyPosition(at: point),
                  pos.row != state.row || pos.column != state.column else { continue }
            // Sliding to another key before lifting re-targets the press.
            guard case .character = keyViews[pos.row][pos.column].spec.action else { continue }
            view(state).isPressed = false
            state.row = pos.row
            state.column = pos.column
            view(state).isPressed = true
            state.longPressTimer?.invalidate()
            showPreview(state)
            scheduleLongPress(state)
        }
    }

    override func touchesEnded(_ endedTouches: Set<UITouch>, with event: UIEvent?) {
        for touch in endedTouches {
            let id = ObjectIdentifier(touch)
            guard let state = touches[id] else { continue }
            finish(id, state, commit: true, point: touch.location(in: self), time: touch.timestamp)
        }
    }

    override func touchesCancelled(_ cancelled: Set<UITouch>, with event: UIEvent?) {
        for touch in cancelled {
            let id = ObjectIdentifier(touch)
            guard let state = touches[id] else { continue }
            finish(id, state, commit: false, point: nil, time: touch.timestamp)
        }
    }

    private func finish(_ id: ObjectIdentifier, _ state: TouchState, commit: Bool, point: CGPoint?, time: TimeInterval) {
        state.invalidateTimers()
        view(state).isPressed = false
        state.popup?.removeFromSuperview()
        touches[id] = nil
        pendingOrder.removeAll { $0 == id }
        guard commit else { return }

        let key = spec(state)
        switch key.action {
        case .delete, .shift, .globe:
            return
        case .character:
            if state.showingAlternates {
                if let option = state.popup?.selectedOption {
                    delegate?.keyboardView(self, perform: .character(option), eventTime: time)
                }
            } else {
                delegate?.keyboardView(self, perform: key.action, eventTime: time)
            }
        case .text:
            if state.showingAlternates, let option = state.popup?.selectedOption {
                delegate?.keyboardView(self, perform: .text(option), eventTime: time)
            } else if let point, view(state).frame.insetBy(dx: -8, dy: -8).contains(point) {
                delegate?.keyboardView(self, perform: key.action, eventTime: time)
            }
        default:
            // Function keys fire only if released on the key, so a mis-press can be aborted.
            if let point, view(state).frame.insetBy(dx: -8, dy: -8).contains(point) {
                delegate?.keyboardView(self, perform: key.action, eventTime: time)
            }
        }
    }

    private func commitPendingCharacters(at time: TimeInterval) {
        for id in pendingOrder {
            guard let state = touches[id], !state.showingAlternates else { continue }
            state.invalidateTimers()
            view(state).isPressed = false
            state.popup?.removeFromSuperview()
            touches[id] = nil
            delegate?.keyboardView(self, perform: spec(state).action, eventTime: time)
        }
        pendingOrder.removeAll { touches[$0] == nil }
    }

    func cancelAllTouches() {
        for state in touches.values {
            state.invalidateTimers()
            state.popup?.removeFromSuperview()
            if state.row < keyViews.count, state.column < keyViews[state.row].count {
                view(state).isPressed = false
            }
        }
        touches.removeAll()
        pendingOrder.removeAll()
    }

    // MARK: Popups & timers

    private func showPreview(_ state: TouchState) {
        state.popup?.removeFromSuperview()
        state.popup = nil
        let keyView = view(state)
        guard showsKeyPreview, case .text(let text) = keyView.spec.label else { return }
        let face = keyView.convert(keyView.faceFrame, to: self)
        let popup = KeyPopupView(keyFaceWidth: face.width)
        popup.showPreview(text, above: face, within: bounds)
        addSubview(popup)
        state.popup = popup
    }

    private func scheduleLongPress(_ state: TouchState) {
        guard spec(state).alternates.count > 1 else { return }
        let timer = Timer(timeInterval: longPressDelay, repeats: false) { [weak self, weak state] _ in
            // Scheduled on the main run loop, so this fires on the main thread.
            MainActor.assumeIsolated {
                guard let self, let state else { return }
                self.showAlternates(state)
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        state.longPressTimer = timer
    }

    private func showAlternates(_ state: TouchState) {
        let keyView = view(state)
        let face = keyView.convert(keyView.faceFrame, to: self)
        state.popup?.removeFromSuperview()
        let popup = KeyPopupView(keyFaceWidth: face.width)
        popup.showAlternates(keyView.spec.alternates, above: face, within: bounds, rightToLeft: isRightToLeft)
        addSubview(popup)
        state.popup = popup
        state.showingAlternates = true
        delegate?.keyboardViewDidTouchDownKey(self)
    }

    private func scheduleDeleteRepeat(_ state: TouchState, delay: TimeInterval) {
        let timer = Timer(timeInterval: delay, repeats: false) { [weak self, weak state] _ in
            MainActor.assumeIsolated {
                guard let self, let state else { return }
                let step = self.deleteSchedule.step(tick: state.deleteTick)
                state.deleteTick += 1
                let action: KeyAction = step.unit == .word ? .deleteWord : .delete
                self.delegate?.keyboardView(self, perform: action, eventTime: nil)
                self.scheduleDeleteRepeat(state, delay: step.interval)
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        state.deleteTimer = timer
    }
}
