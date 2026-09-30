import Foundation
import Testing
@testable import ShortcutCore

struct ShortcutRecognizerTests {
    private let chord: Modifiers = [.control, .shift]

    private func flags(_ modifiers: Modifiers) -> ShortcutEvent { .init(.modifiersChanged, modifiers: modifiers) }
    private func down(_ code: UInt16, _ modifiers: Modifiers, repeat repeating: Bool = false) -> ShortcutEvent {
        .init(.keyDown(code, isRepeat: repeating), modifiers: modifiers)
    }
    private func up(_ code: UInt16, _ modifiers: Modifiers) -> ShortcutEvent { .init(.keyUp(code), modifiers: modifiers) }

    private func switches(_ events: [ShortcutEvent], shortcut: Shortcut = .default) -> [Int] {
        var recognizer = ShortcutRecognizer(shortcut: shortcut)
        return events.indices.filter { recognizer.handle(events[$0]) }
    }

    @Test func testEitherPressAndReleaseOrderTriggersWhenEitherModifierIsReleased() {
        for first: Modifiers in [.control, .shift] {
            for remaining: Modifiers in [.control, .shift] {
                #expect(switches([flags(first), flags(chord), flags(remaining), flags([])]) == [2])
            }
        }
    }

    @Test func testHoldingAndDuplicateFlagsDoNotRetrigger() {
        #expect(switches([flags(chord), flags(chord), flags(chord), flags(.shift), flags([]), flags([])]) == [3])
    }

    @Test func testMultipleLeftAndRightModifierEventsWaitForAggregateRelease() {
        #expect(switches([flags(.control), flags(.control), flags(chord), flags(chord),
                                 flags(chord), flags(.control), flags(.control), flags([])]) == [5])
    }

    @Test func testThirdKeyCancelsEvenWhenReleasedBeforeModifiers() {
        #expect(switches([flags(chord), down(0, chord), up(0, chord), flags(.shift), flags([])]) == [])
    }

    @Test func testThirdKeyCancelsEvenWhenModifiersReleasedFirst() {
        #expect(switches([flags(chord), down(0, chord), flags([]), up(0, [])]) == [])
    }

    @Test func testKeyAfterSwitchBlocksFurtherSwitchesUntilAllKeysAreReleased() {
        #expect(switches([flags(chord), flags(.shift), down(0, .shift), up(0, .shift),
                         flags(chord), flags(.shift), flags([]),
                         flags(chord), flags(.control), flags([])]) == [1, 8])
    }

    @Test func testKeyHeldBeforeModifiersCancels() {
        #expect(switches([down(0, []), flags(.control), flags(chord), up(0, chord), flags([])]) == [])
    }

    @Test func testEarlierShortcutUseCancelsEntireGesture() {
        #expect(switches([flags(.control), down(0, .control), up(0, .control), flags(chord), flags([])]) == [])
    }

    @Test func testExtraModifierBeforeOrDuringReleaseCancels() {
        for extra: Modifiers in [.option, .command, .function] {
            #expect(switches([flags(extra), flags(chord.union(extra)), flags(chord), flags([])]) == [])
            #expect(switches([flags(chord), flags(chord.union(extra)), flags(chord), flags([])]) == [])
            #expect(switches([flags(chord), flags([.shift, extra]), flags(.shift), flags(chord), flags([])]) == [])
        }
    }

    @Test func testExtraModifierAfterSwitchBlocksFurtherSwitchesUntilAllKeysAreReleased() {
        for extra: Modifiers in [.option, .command, .function] {
            #expect(switches([flags(chord), flags(.shift), flags([.shift, extra]),
                             flags(.shift), flags(chord), flags(.shift), flags([]),
                             flags(chord), flags([])]) == [1, 8])
        }
    }

    @Test func testAltShiftCanRepeatWhileEitherModifierRemainsHeld() {
        let shortcut = Shortcut(modifiers: [.option, .shift])
        let mods = shortcut.modifiers
        for first: Modifiers in [.option, .shift] {
            for remaining: Modifiers in [.option, .shift] {
                #expect(switches([flags(first), flags(mods), flags(remaining),
                                 flags(mods), flags(remaining), flags(mods), flags(remaining),
                                 flags([])], shortcut: shortcut) == [2, 4, 6])
            }
        }
    }

    @Test func testRepeatedChordCanAlternateWhichModifierIsReleased() {
        #expect(switches([flags(chord), flags(.shift), flags(chord), flags(.control),
                         flags(chord), flags([]), flags(chord), flags([])]) == [1, 3, 5, 7])
    }

    @Test func testNextCleanGestureWorksAfterCancelledGesture() {
        #expect(switches([flags(chord), down(0, chord), flags([]), up(0, []),
                                 flags(chord), flags([]), flags(chord), flags([])]) == [5, 7])
    }

    @Test func testMouseClickDragAndScrollCancel() {
        for button in 0...4 {
            #expect(switches([flags(chord), .init(.pointerDown(button), modifiers: chord),
                                     .init(.pointerUp(button), modifiers: chord), flags([])]) == [])
            #expect(switches([.init(.pointerDown(button), modifiers: []), flags(chord),
                                     flags([]), .init(.pointerUp(button), modifiers: [])]) == [])
        }
        #expect(switches([flags(chord), .init(.otherAction, modifiers: chord), flags([])]) == [])
    }

    @Test func testMouseActionAfterSwitchBlocksFurtherSwitchesUntilAllKeysAreReleased() {
        for action: ShortcutEvent.Kind in [.pointerDown(0), .otherAction] {
            #expect(switches([flags(chord), flags(.shift), .init(action, modifiers: .shift),
                             .init(.pointerUp(0), modifiers: .shift), flags(chord), flags(.shift),
                             flags([]), flags(chord), flags([])]) == [1, 8])
        }
    }

    @Test func testMissingKeyDownIsConservativelyCancelled() {
        #expect(switches([flags(chord), up(0, chord), flags([])]) == [])
    }

    @Test func testResetPreventsSwitchingAtEndOfInterruptedGesture() {
        var recognizer = ShortcutRecognizer(shortcut: .default)
        #expect(recognizer.handle(flags(chord)) == false)
        recognizer.reset(modifiers: chord)
        #expect(recognizer.handle(flags(.shift)) == false)
        #expect(recognizer.handle(flags(chord)) == false)
        #expect(recognizer.handle(flags(.control)) == false)
        #expect(recognizer.handle(flags([])) == false)
        #expect(recognizer.handle(flags(chord)) == false)
        #expect(recognizer.handle(flags(.shift)) == true)
        #expect(recognizer.handle(flags([])) == false)
    }

    @Test func testHeldKeyAndMouseAtStartupMustBeReleased() {
        var recognizer = ShortcutRecognizer(shortcut: .default)
        recognizer.reset(keysDown: [0], buttonsDown: [0])
        for event in [flags(chord), up(0, chord), flags([]), .init(.pointerUp(0), modifiers: [])] {
            #expect(recognizer.handle(event) == false)
        }
        #expect(recognizer.handle(flags(chord)) == false)
        #expect(recognizer.handle(flags([])) == true)
    }

    @Test func testEveryValidModifierCombination() {
        for raw in UInt8(1)...15 where raw.nonzeroBitCount >= 2 {
            let modifiers = Modifiers(rawValue: raw)
            let shortcut = Shortcut(modifiers: modifiers)
            #expect(shortcut.isValid)
            #expect(switches([flags(modifiers), flags(modifiers), flags([])], shortcut: shortcut) == [2])
            for released: Modifiers in [.control, .shift, .option, .command] where modifiers.contains(released) {
                let remaining = modifiers.subtracting(released)
                #expect(switches([flags(modifiers), flags(remaining), flags(remaining),
                                 flags(modifiers), flags(remaining), flags([])], shortcut: shortcut) == [1, 4])
            }
        }
    }

    @Test func testOrdinaryKeyChordTriggersWhenAnyKeyIsReleased() {
        let shortcut = Shortcut(modifiers: [.control, .option], keyCode: 49)
        let mods = shortcut.modifiers
        #expect(switches([flags(mods), down(49, mods), up(49, mods), flags([])], shortcut: shortcut) == [2])
        #expect(switches([flags(mods), down(49, mods), flags([]), up(49, [])], shortcut: shortcut) == [2])
        for remaining: Modifiers in [.control, .option] {
            #expect(switches([flags(mods), down(49, mods), flags(remaining),
                             up(49, remaining), flags([])], shortcut: shortcut) == [2])
            #expect(switches([flags(mods), down(49, mods), flags(remaining),
                             flags([]), up(49, [])], shortcut: shortcut) == [2])
        }
    }

    @Test func testOrdinaryKeyAutoRepeatTriggersOnce() {
        let shortcut = Shortcut(modifiers: .option, keyCode: 49)
        #expect(switches([flags(.option), down(49, .option), down(49, .option, repeat: true),
                                 down(49, .option, repeat: true), up(49, .option), flags([])], shortcut: shortcut) == [4])
        #expect(switches([flags(.option), down(49, .option), flags([]),
                         down(49, [], repeat: true), up(49, [])], shortcut: shortcut) == [2])
    }

    @Test func testOrdinaryKeyMustFollowItsModifiers() {
        let shortcut = Shortcut(modifiers: .option, keyCode: 49)
        #expect(switches([down(49, []), flags(.option), up(49, .option), flags([])], shortcut: shortcut) == [])
    }

    @Test func testExtraKeyCancelsOrdinaryKeyChord() {
        let shortcut = Shortcut(modifiers: .option, keyCode: 49)
        #expect(switches([flags(.option), down(49, .option), down(0, .option),
                                 up(0, .option), up(49, .option), flags([])], shortcut: shortcut) == [])
    }

    @Test func testOrdinaryKeyCanRepeatWhileModifiersRemainHeld() {
        let shortcut = Shortcut(modifiers: .option, keyCode: 49)
        #expect(switches([flags(.option), down(49, .option), up(49, .option),
                         down(49, .option), up(49, .option), flags([])], shortcut: shortcut) == [2, 4])
    }

    @Test func testModifierCanRepeatWhileOrdinaryKeyRemainsHeld() {
        let shortcut = Shortcut(modifiers: .option, keyCode: 49)
        #expect(switches([flags(.option), down(49, .option), flags([]),
                         flags(.option), flags([]), up(49, [])], shortcut: shortcut) == [2, 4])
        #expect(switches([flags(.option), down(49, .option), flags([]),
                         flags(.option), up(49, .option), flags([])], shortcut: shortcut) == [2, 4])
    }

    @Test func testInvalidConfigurationNeverFires() {
        for shortcut in [Shortcut(modifiers: []), Shortcut(modifiers: .shift),
                         Shortcut(modifiers: [.control, .function]), Shortcut(modifiers: .control, keyCode: 999)] {
            #expect(!shortcut.isValid)
            #expect(switches([flags(shortcut.modifiers), flags([])], shortcut: shortcut) == [])
        }
    }

    @Test func testCancelledChordReportsItsCauseOnceOnRelease() {
        var recognizer = ShortcutRecognizer(shortcut: .default)
        for event in [flags(chord), down(0, chord), up(0, chord)] {
            #expect(recognizer.handle(event) == false)
            #expect(recognizer.lastCancellationReason == nil)
        }
        #expect(recognizer.handle(flags(.shift)) == false)
        #expect(recognizer.lastCancellationReason == .otherKey)
        #expect(recognizer.handle(flags([])) == false)
        #expect(recognizer.lastCancellationReason == nil)

        #expect(recognizer.handle(flags(chord)) == false)
        #expect(recognizer.handle(flags([])) == true)
        #expect(recognizer.lastCancellationReason == nil)
    }

    @Test func testCancellationReasonsDistinguishConflictingActions() {
        let cases: [(ShortcutRecognizer.CancellationReason, [ShortcutEvent])] = [
            (.extraModifier, [flags(chord.union(.option)), flags(chord)]),
            (.unexpectedKeyRelease, [flags(chord), up(0, chord)]),
            (.pointerAction, [flags(chord), .init(.pointerDown(0), modifiers: chord),
                             .init(.pointerUp(0), modifiers: chord)]),
            (.otherAction, [flags(chord), .init(.otherAction, modifiers: chord)]),
            (.otherKey, [down(0, []), flags(chord), up(0, chord)]),
        ]
        for (reason, events) in cases {
            var recognizer = ShortcutRecognizer(shortcut: .default)
            for event in events { #expect(recognizer.handle(event) == false) }
            #expect(recognizer.handle(flags([])) == false)
            #expect(recognizer.lastCancellationReason == reason)
        }
    }

    @Test func testOrdinaryTypingAndPointerActionsDoNotReportShortcutAttempts() {
        var recognizer = ShortcutRecognizer(shortcut: .default)
        let events = [down(0, []), up(0, []), flags(.shift), down(1, .shift), up(1, .shift),
                      flags([]), flags(.control), down(8, .control), up(8, .control), flags([]),
                      .init(.pointerDown(0), modifiers: []), .init(.pointerUp(0), modifiers: []),
                      .init(.otherAction, modifiers: [])]
        for event in events {
            #expect(recognizer.handle(event) == false)
            #expect(recognizer.lastCancellationReason == nil)
        }
    }

    @Test func testInterruptedChordReportsHeldStateAndResetClearsTheReport() {
        var recognizer = ShortcutRecognizer(shortcut: .default)
        recognizer.reset(modifiers: chord)
        #expect(recognizer.handle(flags(.control)) == false)
        #expect(recognizer.lastCancellationReason == .heldAtReset)
        recognizer.reset()
        #expect(recognizer.lastCancellationReason == nil)
        #expect(recognizer.handle(flags(chord)) == false)
        #expect(recognizer.handle(flags([])) == true)
    }

    @Test func testOrdinaryKeyShortcutReportsCancellationOnItsFirstRelease() {
        let shortcut = Shortcut(modifiers: .option, keyCode: 49)
        var recognizer = ShortcutRecognizer(shortcut: shortcut)
        for event in [flags(.option), down(49, .option), down(0, .option), up(0, .option)] {
            #expect(recognizer.handle(event) == false)
            #expect(recognizer.lastCancellationReason == nil)
        }
        #expect(recognizer.handle(up(49, .option)) == false)
        #expect(recognizer.lastCancellationReason == .otherKey)
        #expect(recognizer.handle(flags([])) == false)
        #expect(recognizer.lastCancellationReason == nil)
    }

    @Test func testShortcutSerializationAndPhysicalKeyName() throws {
        let shortcut = Shortcut(modifiers: [.control, .option], keyCode: 49)
        #expect(try JSONDecoder().decode(Shortcut.self, from: JSONEncoder().encode(shortcut)) == shortcut)
        #expect(shortcut.displayName == "⌃ ⌥ Space")
        #expect(Shortcut.default.displayName == "⌃ ⇧")
    }
}
