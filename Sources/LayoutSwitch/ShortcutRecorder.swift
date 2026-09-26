import AppKit
import ShortcutCore

@MainActor
final class ShortcutRecorder {
    private var monitor: Any?
    private var focusObserver: NSObjectProtocol?
    private weak var window: NSWindow?
    private var capture = ShortcutCapture()
    private var functionDown = false
    private var waitingForRelease = false
    var onComplete: ((Shortcut?) -> Void)?
    var onHint: ((String) -> Void)?

    func start(in window: NSWindow) {
        stop()
        self.window = window
        capture = ShortcutCapture()
        functionDown = NSEvent.modifierFlags.contains(.function)
        waitingForRelease = !Modifiers(cgFlags: CGEventFlags(rawValue: UInt64(NSEvent.modifierFlags.rawValue)),
                                       functionDown: functionDown).isEmpty
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.flagsChanged, .keyDown, .keyUp]) {
            [weak self] event in
            let handled = MainActor.assumeIsolated {
                guard let self, event.window === self.window else { return false }
                self.receive(event)
                return true
            }
            return handled ? nil : event
        }
        focusObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didResignKeyNotification, object: window, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.cancel() }
        }
        onHint?("Нажмите сочетание и отпустите все клавиши. Esc — отмена.")
    }

    func cancel() {
        guard monitor != nil else { return }
        stop()
        onComplete?(nil)
    }

    private func stop() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        if let focusObserver { NotificationCenter.default.removeObserver(focusObserver) }
        monitor = nil
        focusObserver = nil
        window = nil
    }

    private func receive(_ event: NSEvent) {
        let kind: ShortcutEvent.Kind
        switch event.type {
        case .flagsChanged:
            if event.keyCode == 63 { functionDown = event.modifierFlags.contains(.function) }
            kind = KeyboardMonitor.modifierCodes.contains(event.keyCode) || event.keyCode == 63
                ? .modifiersChanged : .otherAction
        case .keyDown:
            kind = .keyDown(event.keyCode, isRepeat: event.isARepeat)
        case .keyUp:
            kind = .keyUp(event.keyCode)
        default:
            return
        }
        let flags = CGEventFlags(rawValue: UInt64(event.modifierFlags.rawValue))
        let modifiers = Modifiers(cgFlags: flags, functionDown: functionDown)
        if waitingForRelease {
            if modifiers.isEmpty && event.type != .keyDown { waitingForRelease = false }
            return
        }
        switch capture.handle(ShortcutEvent(kind, modifiers: modifiers)) {
        case .pending:
            break
        case let .captured(shortcut):
            stop()
            onComplete?(shortcut)
        case .cancelled:
            cancel()
        case .rejected:
            onHint?("Нужны два модификатора или модификатор с одной клавишей. Попробуйте ещё раз.")
        }
    }
}
