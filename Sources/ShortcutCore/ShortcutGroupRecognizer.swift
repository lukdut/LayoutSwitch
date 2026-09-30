/// Each shortcut sees every event. Matching shortcuts produce one switch per
/// event, and a successful match takes precedence over other cancellations.
public struct ShortcutGroupRecognizer {
    private var recognizers: [ShortcutRecognizer]
    public private(set) var lastCancellationReasons: [ShortcutRecognizer.CancellationReason] = []

    public init(shortcuts: [Shortcut]) {
        recognizers = Shortcut.normalized(shortcuts).map { ShortcutRecognizer(shortcut: $0) }
    }

    public mutating func reset(
        modifiers: Modifiers = [], keysDown: Set<UInt16> = [], buttonsDown: Set<Int> = []
    ) {
        lastCancellationReasons.removeAll(keepingCapacity: true)
        for index in recognizers.indices {
            recognizers[index].reset(modifiers: modifiers, keysDown: keysDown, buttonsDown: buttonsDown)
        }
    }

    @discardableResult
    public mutating func handle(_ event: ShortcutEvent) -> Bool {
        lastCancellationReasons.removeAll(keepingCapacity: true)
        var triggered = false
        for index in recognizers.indices {
            if recognizers[index].handle(event) { triggered = true }
            if let reason = recognizers[index].lastCancellationReason,
               !lastCancellationReasons.contains(reason) {
                lastCancellationReasons.append(reason)
            }
        }
        if triggered {
            lastCancellationReasons.removeAll(keepingCapacity: true)
            for index in recognizers.indices { recognizers[index].prepareForNextShortcut() }
        }
        return triggered
    }
}
