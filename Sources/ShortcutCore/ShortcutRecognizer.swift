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
/// No event is suppressed. A conflict blocks switching until all keys are up.
public struct ShortcutRecognizer {
    public enum CancellationReason: String, Sendable {
        case heldAtReset, extraModifier, otherKey, unexpectedKeyRelease, pointerAction, otherAction
    }

    public let shortcut: Shortcut
    /// Reported once when a cancelled chord is released, never for ordinary typing.
    public private(set) var lastCancellationReason: CancellationReason?
    private var modifiers: Modifiers = []
    private var keysDown: Set<UInt16> = []
    private var buttonsDown: Set<Int> = []
    private var armed = false
    private var waitingForChordRelease = false
    private var cancellationReason: CancellationReason?
    private var attempted = false
    private var cancelled: Bool { cancellationReason != nil }
    private var shortcutKeysHeld: Bool {
        modifiers.isSuperset(of: shortcut.modifiers) &&
            (shortcut.keyCode.map { keysDown.contains($0) } ?? true)
    }
    private var chordHeld: Bool {
        modifiers == shortcut.modifiers &&
            (shortcut.keyCode.map { keysDown == [$0] } ?? keysDown.isEmpty)
    }

    public init(shortcut: Shortcut) { self.shortcut = shortcut }

    /// Used after startup, wake, a tap interruption, or a configuration change.
    /// An already-held chord must be released before a new gesture can start.
    public mutating func reset(
        modifiers: Modifiers = [], keysDown: Set<UInt16> = [], buttonsDown: Set<Int> = []
    ) {
        self.modifiers = modifiers
        self.keysDown = keysDown
        self.buttonsDown = buttonsDown
        armed = false
        waitingForChordRelease = false
        cancellationReason = !modifiers.isEmpty || !keysDown.isEmpty || !buttonsDown.isEmpty ? .heldAtReset : nil
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
        let matchingKeys = shortcut.keyCode.map { keysDown.isSubset(of: [$0]) } ?? keysDown.isEmpty
        cancellationReason = !modifiers.subtracting(shortcut.modifiers).isEmpty ||
            !matchingKeys || !buttonsDown.isEmpty ? .heldAtReset : nil
    }

    @discardableResult
    public mutating func handle(_ event: ShortcutEvent) -> Bool {
        lastCancellationReason = nil
        modifiers = event.modifiers

        if !modifiers.subtracting(shortcut.modifiers).isEmpty { cancel(.extraModifier) }

        switch event.kind {
        case .modifiersChanged:
            break
        case let .keyDown(code, isRepeat):
            let alreadyDown = keysDown.contains(code)
            keysDown.insert(code)
            if isRepeat && alreadyDown { break }
            if code != shortcut.keyCode || modifiers != shortcut.modifiers ||
                keysDown.count != 1 || isRepeat {
                cancel(.otherKey)
            }
        case let .keyUp(code):
            if !keysDown.contains(code) { cancel(.unexpectedKeyRelease) }
            keysDown.remove(code)
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
        lastCancellationReason = rejectedBecause
        return shouldSwitch
    }

    private mutating func cancel(_ reason: CancellationReason) {
        if cancellationReason == nil { cancellationReason = reason }
    }
}
