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
    public let shortcut: Shortcut
    private var modifiers: Modifiers = []
    private var keysDown: Set<UInt16> = []
    private var buttonsDown: Set<Int> = []
    private var armed = false
    private var cancelled = false

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
        cancelled = !modifiers.isEmpty || !keysDown.isEmpty || !buttonsDown.isEmpty
    }

    @discardableResult
    public mutating func handle(_ event: ShortcutEvent) -> Bool {
        modifiers = event.modifiers

        if !modifiers.subtracting(shortcut.modifiers).isEmpty { cancelled = true }

        switch event.kind {
        case .modifiersChanged:
            break
        case let .keyDown(code, isRepeat):
            let alreadyDown = keysDown.contains(code)
            keysDown.insert(code)
            if isRepeat && alreadyDown { break }
            if code != shortcut.keyCode || modifiers != shortcut.modifiers ||
                keysDown.count != 1 || isRepeat {
                cancelled = true
            }
        case let .keyUp(code):
            if !keysDown.contains(code) { cancelled = true }
            keysDown.remove(code)
        case let .pointerDown(button):
            buttonsDown.insert(button)
            cancelled = true
        case let .pointerUp(button):
            buttonsDown.remove(button)
            cancelled = true
        case .otherAction:
            cancelled = true
        }

        let matchingKeys = shortcut.keyCode.map { keysDown == [$0] } ?? keysDown.isEmpty
        let chordHeld = modifiers == shortcut.modifiers && matchingKeys
        let shouldSwitch = shortcut.isValid && armed && !chordHeld && !cancelled
        armed = chordHeld && !cancelled
        if modifiers.isEmpty && keysDown.isEmpty && buttonsDown.isEmpty { reset() }
        return shouldSwitch
    }
}
