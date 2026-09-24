import Foundation

/// What the engine needs to know about the host text field. The extension builds this
/// from `UITextDocumentProxy`; tests build it by hand.
public struct TextContext: Sendable, Equatable {
    public var before: String?
    public var autocap: AutocapMode

    public init(before: String?, autocap: AutocapMode = .sentences) {
        self.before = before
        self.autocap = autocap
    }
}

public struct EngineSettings: Sendable, Equatable {
    public var doubleSpacePeriod: Bool = true
    /// Arabic double-space behaviour is tested separately (UX spec §19), so it is off by default.
    public var doubleSpacePeriodArabic: Bool = false
    public var doubleSpaceWindow: TimeInterval = 0.45
    public var shiftDoubleTapWindow: TimeInterval = 0.35

    public init() {}
}

/// Keyboard state machine: turns key actions into text operations. It has no UIKit
/// dependency so typing behaviour can be unit-tested off-device.
public final class KeyboardEngine {
    public private(set) var language: KeyboardLanguage
    public private(set) var page: KeyboardPage = .letters
    public private(set) var shift: ShiftState = .off
    public var settings: EngineSettings

    private var lastSpaceTime: TimeInterval?
    private var lastShiftTapTime: TimeInterval?

    public init(language: KeyboardLanguage = .arabic, settings: EngineSettings = EngineSettings()) {
        self.language = language
        self.settings = settings
    }

    /// Output text for a character key, with the current shift applied.
    public func output(for character: String) -> String {
        guard language == .english, page == .letters, shift != .off else { return character }
        return character.uppercased()
    }

    public func handle(_ action: KeyAction, context: TextContext, time: TimeInterval) -> [TextOperation] {
        if action != .space { lastSpaceTime = nil }
        if action != .shift { lastShiftTapTime = nil }

        switch action {
        case .character(let c):
            let ops: [TextOperation] = [.insert(output(for: c))]
            if shift == .on { shift = .off }
            return ops

        case .text(let t):
            return t.isEmpty ? [] : [.insert(t)]

        case .space:
            if page == .symbols { page = .letters }
            let doubleSpaceEnabled = language == .arabic
                ? settings.doubleSpacePeriodArabic : settings.doubleSpacePeriod
            if doubleSpaceEnabled,
               let last = lastSpaceTime, time - last <= settings.doubleSpaceWindow,
               TextEditing.canInsertPeriodOnDoubleSpace(before: context.before) {
                lastSpaceTime = nil
                return [.deleteBackward(1), .insert(". ")]
            }
            lastSpaceTime = time
            return [.insert(" ")]

        case .delete:
            return [.deleteBackward(1)]

        case .deleteWord:
            return [.deleteBackward(TextEditing.wordDeletionLength(before: context.before))]

        case .returnKey:
            return [.insert("\n")]

        case .shift:
            guard language == .english else { return [] }
            switch shift {
            case .off:
                shift = .on
                lastShiftTapTime = time
            case .on:
                if let last = lastShiftTapTime, time - last <= settings.shiftDoubleTapWindow {
                    shift = .locked
                    lastShiftTapTime = nil
                } else {
                    shift = .off
                }
            case .locked:
                shift = .off
            }
            return []

        case .languageToggle:
            language = language.toggled
            page = .letters
            shift = .off
            updateAutoShift(context: context)
            return []

        case .page(let p):
            page = p
            return []

        case .globe:
            return []
        }
    }

    /// Replaces the partial word before the cursor with a prediction and adds a space
    /// (UX spec §6). The active layout never changes (§34).
    public func acceptCandidate(_ candidate: String, context: TextContext) -> [TextOperation] {
        lastSpaceTime = nil
        lastShiftTapTime = nil
        let token = TextEditing.currentToken(before: context.before)
        var ops: [TextOperation] = []
        if !token.isEmpty { ops.append(.deleteBackward(token.count)) }
        ops.append(.insert(candidate + " "))
        if shift == .on { shift = .off }
        return ops
    }

    /// Re-evaluates automatic capitalization after the text or cursor changed.
    /// Caps lock is never overridden.
    public func updateAutoShift(context: TextContext) {
        guard shift != .locked else { return }
        guard language == .english else {
            shift = .off
            return
        }
        shift = TextEditing.shouldAutoCapitalize(before: context.before, mode: context.autocap) ? .on : .off
    }

    public func setLanguage(_ language: KeyboardLanguage) {
        self.language = language
        page = .letters
        shift = .off
    }

    public func layoutContext(field: FieldKind, returnKind: ReturnKind, needsGlobe: Bool) -> LayoutContext {
        LayoutContext(language: language, page: page, shift: shift, field: field,
                      returnKind: returnKind, needsGlobe: needsGlobe)
    }
}
