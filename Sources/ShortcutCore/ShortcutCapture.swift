public struct ShortcutCapture {
    public enum Result: Equatable {
        case pending
        case captured(Shortcut)
        case rejected
        case cancelled
    }

    private var peak: Modifiers = []
    private var previous: Modifiers = []
    private var heldKeys: Set<UInt16> = []
    private var keyCode: UInt16?
    private var releasing = false
    private var invalid = false
    private var began = false

    public init() {}

    public mutating func handle(_ event: ShortcutEvent) -> Result {
        if case .keyDown(53, _) = event.kind, event.modifiers.isEmpty {
            self = Self()
            return .cancelled
        }
        let modifiers = event.modifiers
        if !modifiers.subtracting(.assignable).isEmpty { invalid = true }
        if keyCode != nil && !modifiers.subtracting(previous).isEmpty { invalid = true }
        if releasing && !modifiers.subtracting(previous).isEmpty { invalid = true }
        if !previous.subtracting(modifiers).isEmpty { releasing = true }
        if !releasing { peak.formUnion(modifiers) }
        previous = modifiers
        began = began || !modifiers.isEmpty

        switch event.kind {
        case .modifiersChanged:
            break
        case let .keyDown(code, isRepeat):
            let alreadyDown = heldKeys.contains(code)
            heldKeys.insert(code)
            began = true
            if !(isRepeat && alreadyDown) {
                if keyCode == nil && !releasing && !modifiers.isEmpty {
                    keyCode = code
                } else {
                    invalid = true
                }
            }
        case let .keyUp(code):
            if !heldKeys.contains(code) { invalid = true }
            heldKeys.remove(code)
            releasing = true
        default:
            invalid = true
        }

        guard began && modifiers.isEmpty && heldKeys.isEmpty else { return .pending }
        let shortcut = Shortcut(modifiers: peak, keyCode: keyCode)
        let result: Result = !invalid && shortcut.isValid ? .captured(shortcut) : .rejected
        self = Self()
        return result
    }
}
