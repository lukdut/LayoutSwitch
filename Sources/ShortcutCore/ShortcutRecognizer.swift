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

/// One gesture lasts until ALL keys and modifiers have been released.
/// No event is suppressed. A conflicting action cancels the whole gesture.
public struct ShortcutRecognizer {
    public let shortcut: Shortcut
    private var modifiers: Modifiers = []
    private var keysDown: Set<UInt16> = []
    private var buttonsDown: Set<Int> = []
    private var armed = false
    private var cancelled = false
    private var releasing = false

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
        releasing = false
        cancelled = !modifiers.isEmpty || !keysDown.isEmpty || !buttonsDown.isEmpty
    }

    @discardableResult
    public mutating func handle(_ event: ShortcutEvent) -> Bool {
        let previousModifiers = modifiers
        modifiers = event.modifiers

        if !modifiers.subtracting(shortcut.modifiers).isEmpty { cancelled = true }
        if releasing && !modifiers.subtracting(previousModifiers).isEmpty { cancelled = true }
        if armed && !previousModifiers.subtracting(modifiers).isEmpty { releasing = true }

        switch event.kind {
        case .modifiersChanged:
            if shortcut.keyCode == nil && modifiers == shortcut.modifiers && keysDown.isEmpty {
                armed = true
            }
        case let .keyDown(code, isRepeat):
            let alreadyDown = keysDown.contains(code)
            keysDown.insert(code)
            if isRepeat && alreadyDown { break }
            if code == shortcut.keyCode && modifiers == shortcut.modifiers &&
                keysDown.count == 1 && !releasing && !isRepeat {
                armed = true
            } else {
                cancelled = true
            }
        case let .keyUp(code):
            if !keysDown.contains(code) { cancelled = true }
            keysDown.remove(code)
            if armed { releasing = true }
        case let .pointerDown(button):
            buttonsDown.insert(button)
            cancelled = true
        case let .pointerUp(button):
            buttonsDown.remove(button)
            cancelled = true
        case .otherAction:
            cancelled = true
        }

        guard modifiers.isEmpty && keysDown.isEmpty && buttonsDown.isEmpty else { return false }
        let shouldSwitch = shortcut.isValid && armed && !cancelled
        reset()
        return shouldSwitch
    }
}
