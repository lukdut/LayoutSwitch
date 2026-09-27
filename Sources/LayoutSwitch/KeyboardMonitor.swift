import AppKit
import Carbon
import OSLog
import ShortcutCore

extension Modifiers {
    init(cgFlags: CGEventFlags, functionDown: Bool) {
        self = []
        if cgFlags.contains(.maskControl) { insert(.control) }
        if cgFlags.contains(.maskShift) { insert(.shift) }
        if cgFlags.contains(.maskAlternate) { insert(.option) }
        if cgFlags.contains(.maskCommand) { insert(.command) }
        if functionDown { insert(.function) }
    }
}

/// The tap and every callback run on the main run loop. The callback only
/// handles key codes/flags; it never asks for characters or retains events.
@MainActor
final class KeyboardMonitor {
    static let modifierCodes: Set<UInt16> = [54, 55, 56, 58, 59, 60, 61, 62]
    private static let latencyLog = Logger(subsystem: "local.masos.LayoutSwitch", category: "SwitchLatency")
    private var tap: CFMachPort?
    private var source: CFRunLoopSource?
    private var recognizer = ShortcutRecognizer(shortcut: .default)
    private var functionDown = false
    private var generation = 0
    var onTrigger: (() -> Void)?
    var onInterruption: (() -> Void)?
    var isRunning: Bool { tap.map { CGEvent.tapIsEnabled(tap: $0) } ?? false }

    func start(shortcut: Shortcut) -> Bool {
        stop()
        guard CGPreflightListenEventAccess(), !IsSecureEventInputEnabled() else { return false }
        recognizer = ShortcutRecognizer(shortcut: shortcut)
        resetGesture()
        let types: [CGEventType] = [
            .flagsChanged, .keyDown, .keyUp, .leftMouseDown, .leftMouseUp,
            .rightMouseDown, .rightMouseUp, .otherMouseDown, .otherMouseUp,
            .scrollWheel, .leftMouseDragged, .rightMouseDragged, .otherMouseDragged,
        ]
        let mask = types.reduce(CGEventMask(0)) { $0 | (CGEventMask(1) << $1.rawValue) }
        guard let newTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap, place: .headInsertEventTap, options: .listenOnly,
            eventsOfInterest: mask,
            callback: { _, type, event, context in
                guard let context else { return Unmanaged.passUnretained(event) }
                MainActor.assumeIsolated {
                    let monitor = Unmanaged<KeyboardMonitor>.fromOpaque(context).takeUnretainedValue()
                    monitor.receive(type: type, event: event)
                }
                return Unmanaged.passUnretained(event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else { return false }
        guard let newSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, newTap, 0) else {
            CFMachPortInvalidate(newTap)
            return false
        }
        tap = newTap
        source = newSource
        CFRunLoopAddSource(CFRunLoopGetMain(), newSource, .commonModes)
        CGEvent.tapEnable(tap: newTap, enable: true)
        return true
    }

    func stop() {
        generation += 1
        if let tap {
            CGEvent.tapEnable(tap: tap, enable: false)
            CFMachPortInvalidate(tap)
        }
        if let source { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes) }
        source = nil
        tap = nil
        recognizer.reset()
    }

    private func resetGesture() {
        generation += 1
        let flags = CGEventSource.flagsState(.combinedSessionState)
        functionDown = flags.contains(.maskSecondaryFn)
        let keys = Set((UInt16(0)...127).filter {
            !Self.modifierCodes.contains($0) && $0 != 57 && $0 != 63 &&
                CGEventSource.keyState(.combinedSessionState, key: $0)
        })
        let buttons = Set((0...4).filter {
            CGEventSource.buttonState(.combinedSessionState, button: CGMouseButton(rawValue: UInt32($0))!)
        })
        recognizer.reset(modifiers: Modifiers(cgFlags: flags, functionDown: functionDown),
                         keysDown: keys, buttonsDown: buttons)
    }

    private func receive(type: CGEventType, event: CGEvent) {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            resetGesture()
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            onInterruption?()
            return
        }
        // Check every event as well as the periodic health check. Discard any
        // unfinished gesture whenever secure input is detected.
        guard !IsSecureEventInputEnabled() else { resetGesture(); return }
        let code = UInt16(clamping: event.getIntegerValueField(.keyboardEventKeycode))
        let kind: ShortcutEvent.Kind
        switch type {
        case .flagsChanged:
            if code == 63 { functionDown = event.flags.contains(.maskSecondaryFn) }
            kind = Self.modifierCodes.contains(code) || code == 63 ? .modifiersChanged : .otherAction
        case .keyDown:
            kind = .keyDown(code, isRepeat: event.getIntegerValueField(.keyboardEventAutorepeat) != 0)
        case .keyUp:
            kind = .keyUp(code)
        case .leftMouseDown, .rightMouseDown, .otherMouseDown:
            kind = .pointerDown(Int(event.getIntegerValueField(.mouseEventButtonNumber)))
        case .leftMouseUp, .rightMouseUp, .otherMouseUp:
            kind = .pointerUp(Int(event.getIntegerValueField(.mouseEventButtonNumber)))
        default:
            kind = .otherAction
        }
        let modifiers = Modifiers(cgFlags: event.flags, functionDown: functionDown)
        if recognizer.handle(ShortcutEvent(kind, modifiers: modifiers)) {
            // Input source selection can involve IPC. Keep it outside the tap.
            // Common modes also run while our menu or a modal loop is active.
            let expectedGeneration = generation
            let receivedAt = DispatchTime.now().uptimeNanoseconds
            let eventTime = event.timestamp
            let eventAt = eventTime > 0 ? min(eventTime, receivedAt) : receivedAt
            CFRunLoopPerformBlock(CFRunLoopGetMain(), CFRunLoopMode.commonModes.rawValue) { [weak self] in
                MainActor.assumeIsolated {
                    guard let self, self.generation == expectedGeneration,
                          self.isRunning, !IsSecureEventInputEnabled() else { return }
                    let startedAt = DispatchTime.now().uptimeNanoseconds
                    self.onTrigger?()
                    let finishedAt = DispatchTime.now().uptimeNanoseconds
                    if finishedAt - eventAt >= 100_000_000 {
                        let deliveryMS = Double(receivedAt - eventAt) / 1_000_000
                        let queueMS = Double(startedAt - receivedAt) / 1_000_000
                        let switchMS = Double(finishedAt - startedAt) / 1_000_000
                        Self.latencyLog.notice("Slow layout switch: delivery=\(deliveryMS, privacy: .public) ms, queue=\(queueMS, privacy: .public) ms, switch=\(switchMS, privacy: .public) ms")
                    }
                }
            }
        }
    }
}
