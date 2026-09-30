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
    private static let shortcutLog = Logger(subsystem: "local.masos.LayoutSwitch", category: "Shortcut")
    private var tap: CFMachPort?
    private var source: CFRunLoopSource?
    private var recognizer = ShortcutGroupRecognizer(shortcuts: [.default])
    private var functionDown = false
    private var generation = 0
    var onTrigger: (() -> LayoutSwitchTimings?)?
    var onInterruption: (() -> Void)?
    var isRunning: Bool { tap.map { CGEvent.tapIsEnabled(tap: $0) } ?? false }

    func start(shortcuts: [Shortcut]) -> Bool {
        stop()
        guard !Shortcut.normalized(shortcuts).isEmpty else { return false }
        guard CGPreflightListenEventAccess(), !IsSecureEventInputEnabled() else { return false }
        recognizer = ShortcutGroupRecognizer(shortcuts: shortcuts)
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
            let reason = type == .tapDisabledByTimeout ? "timeout" : "userInput"
            Self.latencyLog.notice("Keyboard tap interrupted: \(reason, privacy: .public)")
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
        let triggered = recognizer.handle(ShortcutEvent(kind, modifiers: modifiers))
        for reason in recognizer.lastCancellationReasons {
            Self.shortcutLog.notice("Shortcut cancelled: \(reason.rawValue, privacy: .public)")
        }
        if triggered {
            Self.shortcutLog.notice("Shortcut recognized")
            // Input source selection can involve IPC. Keep it outside the tap.
            // Common modes also run while our menu or a modal loop is active.
            let expectedGeneration = generation
            let receivedAt = DispatchTime.now().uptimeNanoseconds
            let eventTime = event.timestamp
            let eventAt = eventTime > 0 ? min(eventTime, receivedAt) : receivedAt
            CFRunLoopPerformBlock(CFRunLoopGetMain(), CFRunLoopMode.commonModes.rawValue) { [weak self] in
                MainActor.assumeIsolated {
                    guard let self else { return }
                    guard self.generation == expectedGeneration else {
                        Self.shortcutLog.notice("Queued switch cancelled: monitoring changed")
                        return
                    }
                    guard self.isRunning else {
                        Self.shortcutLog.notice("Queued switch cancelled: monitoring stopped")
                        return
                    }
                    guard !IsSecureEventInputEnabled() else {
                        Self.shortcutLog.notice("Queued switch cancelled: secure input")
                        return
                    }
                    let startedAt = DispatchTime.now().uptimeNanoseconds
                    let timings = self.onTrigger?()
                    let finishedAt = DispatchTime.now().uptimeNanoseconds
                    if let timings {
                        let outcome = timings.inputSource.outcome.rawValue
                        let code = timings.inputSource.statusCode.map { String($0) } ?? "none"
                        Self.shortcutLog.notice("Shortcut handled: outcome=\(outcome, privacy: .public), status=\(code, privacy: .public)")
                    } else {
                        Self.shortcutLog.notice("Shortcut handler skipped switching")
                    }
                    if finishedAt - eventAt >= 100_000_000 {
                        let deliveryMS = Double(receivedAt - eventAt) / 1_000_000
                        let queueMS = Double(startedAt - receivedAt) / 1_000_000
                        let switchMS = Double(finishedAt - startedAt) / 1_000_000
                        Self.latencyLog.notice("Slow layout switch: delivery=\(deliveryMS, privacy: .public) ms, queue=\(queueMS, privacy: .public) ms, switch=\(switchMS, privacy: .public) ms")
                        if let timings {
                            let source = timings.inputSource
                            Self.latencyLog.notice("Switch phases: readCurrent=\(source.readCurrentMS, privacy: .public) ms, prepare=\(source.prepareMS, privacy: .public) ms, select=\(source.selectMS, privacy: .public) ms, confirm=\(source.confirmMS, privacy: .public) ms, publish=\(timings.publishMS, privacy: .public) ms")
                        }
                    }
                }
            }
        }
    }
}
