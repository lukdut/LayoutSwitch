public struct ShortcutEvent: Sendable {
    public enum Kind: Sendable {
        case modifiersChanged
        case keyDown(UInt16, isRepeat: Bool)
        case keyUp(UInt16)
        case pointerDown(Int)
        case pointerUp(Int)
        case otherAction
    }

    public var kind: Kind
    public var modifiers: Modifiers
    public init(_ kind: Kind, modifiers: Modifiers) {
        self.kind = kind
        self.modifiers = modifiers
    }
}

/// A complete chord triggers once when any of its keys is released.
/// Completing it again rearms the shortcut while other keys remain held.
/// Keys from preceding plain or Shift-only typing may overlap the chord.
/// No event is suppressed. A conflict blocks switching until the gesture's
/// modifiers, keys and buttons are up; preceding typing need not be released.
public struct ShortcutRecognizer {
    public enum CancellationReason: String, Sendable {
        case heldAtReset, extraModifier, otherKey, unexpectedKeyRelease, pointerAction, otherAction
    }

    public let shortcut: Shortcut
    /// Reported once when a cancelled chord is released, never for ordinary typing.
    public private(set) var lastCancellationReason: CancellationReason?
    private var modifiers: Modifiers = []
    private var keysDown: Set<UInt16> = []
    private var precedingKeysDown: Set<UInt16> = []
    private var acceptingTyping = true
    private var buttonsDown: Set<Int> = []
    private var armed = false
    private var waitingForChordRelease = false
    private var cancellationReason: CancellationReason?
    private var attempted = false
    private var cancelled: Bool { cancellationReason != nil }
    // Shift alone is also used for typing. For a Shift + key shortcut,
    // Shift itself starts the gesture, so its key must still follow it.
    private var onlyTypingModifiersHeld: Bool {
        modifiers.isEmpty || (modifiers == .shift && shortcut.modifiers != .shift)
    }
    private var shortcutKeysDown: Set<UInt16> { keysDown.subtracting(precedingKeysDown) }
    private var shortcutKeysHeld: Bool {
        modifiers.isSuperset(of: shortcut.modifiers) &&
            (shortcut.keyCode.map { shortcutKeysDown.contains($0) } ?? true)
    }
    private var chordHeld: Bool {
        modifiers == shortcut.modifiers &&
            (shortcut.keyCode.map { shortcutKeysDown == [$0] } ?? shortcutKeysDown.isEmpty)
    }

    public init(shortcut: Shortcut) { self.shortcut = shortcut }

    /// Used after startup, wake, a tap interruption, or a configuration change.
    /// An already-held chord must be released before a new gesture can start.
    public mutating func reset(
        modifiers: Modifiers = [], keysDown: Set<UInt16> = [], buttonsDown: Set<Int> = []
    ) {
        self.modifiers = modifiers
        self.keysDown = keysDown
        precedingKeysDown.removeAll()
        self.buttonsDown = buttonsDown
        armed = false
        waitingForChordRelease = false
        cancellationReason = !modifiers.isEmpty || !keysDown.isEmpty || !buttonsDown.isEmpty ? .heldAtReset : nil
        acceptingTyping = !cancelled
        attempted = shortcut.isValid && shortcutKeysHeld
        lastCancellationReason = nil
    }

    // A recognized alternative starts a new gesture. Keep the actual held keys
    // so shared modifiers can be reused, but do not arm an inherited full chord:
    // it must be broken and completed again before it can trigger.
    mutating func prepareForNextShortcut() {
        armed = false
        attempted = false
        lastCancellationReason = nil
        waitingForChordRelease = chordHeld
        if acceptingTyping { return }
        if onlyTypingModifiersHeld && shortcutKeysDown.isEmpty && buttonsDown.isEmpty {
            resumeTyping()
            return
        }
        let matchingKeys = shortcut.keyCode.map { shortcutKeysDown.isSubset(of: [$0]) } ?? shortcutKeysDown.isEmpty
        cancellationReason = !modifiers.subtracting(shortcut.modifiers).isEmpty ||
            !matchingKeys || !buttonsDown.isEmpty ? .heldAtReset : nil
    }

    @discardableResult
    public mutating func handle(_ event: ShortcutEvent) -> Bool {
        lastCancellationReason = nil
        modifiers = event.modifiers

        if acceptingTyping && !onlyTypingModifiersHeld {
            precedingKeysDown = keysDown
            acceptingTyping = false
        }
        if !acceptingTyping && !modifiers.subtracting(shortcut.modifiers).isEmpty { cancel(.extraModifier) }

        switch event.kind {
        case .modifiersChanged:
            break
        case let .keyDown(code, isRepeat):
            let alreadyDown = keysDown.contains(code)
            keysDown.insert(code)
            if acceptingTyping {
                if !KeyNames.typingKeyCodes.contains(code) { cancel(.otherKey) }
                break
            }
            if precedingKeysDown.contains(code) {
                // Holding Backspace while moving into a layout shortcut keeps
                // generating repeats. They belong to the preceding deletion,
                // not a new shortcut action. A fresh press still conflicts.
                if code == 51 && isRepeat && alreadyDown { break }
                cancel(.otherKey)
                break
            }
            if isRepeat && alreadyDown { break }
            if code != shortcut.keyCode || modifiers != shortcut.modifiers ||
                shortcutKeysDown.count != 1 || isRepeat {
                cancel(.otherKey)
            }
        case let .keyUp(code):
            if !keysDown.contains(code) { cancel(.unexpectedKeyRelease) }
            keysDown.remove(code)
            precedingKeysDown.remove(code)
        case let .pointerDown(button):
            buttonsDown.insert(button)
            cancel(.pointerAction)
        case let .pointerUp(button):
            buttonsDown.remove(button)
            cancel(.pointerAction)
        case .otherAction:
            cancel(.otherAction)
        }

        if shortcut.isValid && shortcutKeysHeld { attempted = true }
        let rejectedBecause = attempted && !shortcutKeysHeld ? cancellationReason : nil
        if !shortcutKeysHeld { attempted = false }
        let shouldSwitch = shortcut.isValid && armed && !chordHeld && !cancelled
        armed = chordHeld && !cancelled && !waitingForChordRelease
        if !chordHeld { waitingForChordRelease = false }
        if modifiers.isEmpty && keysDown.isEmpty && buttonsDown.isEmpty { reset() }
        else if !acceptingTyping && shortcutKeysDown.isEmpty && buttonsDown.isEmpty &&
            (modifiers.isEmpty || (!cancelled && onlyTypingModifiersHeld)) {
            // A clean gesture may return to Shift-only typing. A cancelled one
            // must release every modifier, but neither needs to wait for keys
            // that were already held before it began.
            resumeTyping()
        }
        lastCancellationReason = rejectedBecause
        return shouldSwitch
    }

    private mutating func cancel(_ reason: CancellationReason) {
        acceptingTyping = false
        if cancellationReason == nil { cancellationReason = reason }
    }

    private mutating func resumeTyping() {
        // Retain actual held keys so their later keyUp is still recognized.
        precedingKeysDown.removeAll()
        acceptingTyping = true
        cancellationReason = nil
        armed = false
        waitingForChordRelease = false
        attempted = false
    }
}
