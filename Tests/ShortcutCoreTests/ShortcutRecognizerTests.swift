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

    @Test func testEitherPressAndReleaseOrderTriggersOnlyAfterLastRelease() {
        for first: Modifiers in [.control, .shift] {
            for remaining: Modifiers in [.control, .shift] {
                #expect(switches([flags(first), flags(chord), flags(remaining), flags([])]) == [3])
            }
        }
    }

    @Test func testHoldingAndDuplicateFlagsDoNotRetrigger() {
        #expect(switches([flags(chord), flags(chord), flags(chord), flags(.shift), flags([]), flags([])]) == [4])
    }

    @Test func testMultipleLeftAndRightModifierEventsWaitForAggregateRelease() {
        #expect(switches([flags(.control), flags(.control), flags(chord), flags(chord),
                                 flags(chord), flags(.control), flags(.control), flags([])]) == [7])
    }

    @Test func testThirdKeyCancelsEvenWhenReleasedBeforeModifiers() {
        #expect(switches([flags(chord), down(0, chord), up(0, chord), flags(.shift), flags([])]) == [])
    }

    @Test func testThirdKeyCancelsEvenWhenModifiersReleasedFirst() {
        #expect(switches([flags(chord), down(0, chord), flags([]), up(0, [])]) == [])
    }

    @Test func testKeyAfterPartialModifierReleaseStillCancels() {
        #expect(switches([flags(chord), flags(.shift), down(0, .shift), up(0, .shift), flags([])]) == [])
    }

    @Test func testKeyHeldBeforeModifiersCancels() {
        #expect(switches([down(0, []), flags(.control), flags(chord), up(0, chord), flags([])]) == [])
    }

    @Test func testEarlierShortcutUseCancelsEntireGesture() {
        #expect(switches([flags(.control), down(0, .control), up(0, .control), flags(chord), flags([])]) == [])
    }

    @Test func testExtraModifierAtEveryStageCancels() {
        for extra: Modifiers in [.option, .command, .function] {
            #expect(switches([flags(extra), flags(chord.union(extra)), flags(chord), flags([])]) == [])
            #expect(switches([flags(chord), flags(chord.union(extra)), flags(chord), flags([])]) == [])
            #expect(switches([flags(chord), flags(.shift), flags([.shift, extra]), flags([])]) == [])
        }
    }

    @Test func testRepressingAModifierDuringReleaseCancels() {
        #expect(switches([flags(chord), flags(.shift), flags(chord), flags([])]) == [])
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

    @Test func testMissingKeyDownIsConservativelyCancelled() {
        #expect(switches([flags(chord), up(0, chord), flags([])]) == [])
    }

    @Test func testResetPreventsSwitchingAtEndOfInterruptedGesture() {
        var recognizer = ShortcutRecognizer(shortcut: .default)
        #expect(recognizer.handle(flags(chord)) == false)
        recognizer.reset(modifiers: chord)
        #expect(recognizer.handle(flags(.shift)) == false)
        #expect(recognizer.handle(flags([])) == false)
        #expect(recognizer.handle(flags(chord)) == false)
        #expect(recognizer.handle(flags([])) == true)
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
        }
    }

    @Test func testOrdinaryKeyChordWaitsForKeysAndModifiersInEitherReleaseOrder() {
        let shortcut = Shortcut(modifiers: [.control, .option], keyCode: 49)
        let mods = shortcut.modifiers
        #expect(switches([flags(mods), down(49, mods), up(49, mods), flags([])], shortcut: shortcut) == [3])
        #expect(switches([flags(mods), down(49, mods), flags([]), up(49, [])], shortcut: shortcut) == [3])
    }

    @Test func testOrdinaryKeyAutoRepeatTriggersOnce() {
        let shortcut = Shortcut(modifiers: .option, keyCode: 49)
        #expect(switches([flags(.option), down(49, .option), down(49, .option, repeat: true),
                                 down(49, .option, repeat: true), up(49, .option), flags([])], shortcut: shortcut) == [5])
    }

    @Test func testOrdinaryKeyMustFollowItsModifiers() {
        let shortcut = Shortcut(modifiers: .option, keyCode: 49)
        #expect(switches([down(49, []), flags(.option), up(49, .option), flags([])], shortcut: shortcut) == [])
    }

    @Test func testExtraKeyAndRepeatedPressCancelOrdinaryKeyChord() {
        let shortcut = Shortcut(modifiers: .option, keyCode: 49)
        #expect(switches([flags(.option), down(49, .option), down(0, .option),
                                 up(0, .option), up(49, .option), flags([])], shortcut: shortcut) == [])
        #expect(switches([flags(.option), down(49, .option), up(49, .option),
                                 down(49, .option), up(49, .option), flags([])], shortcut: shortcut) == [])
    }

    @Test func testInvalidConfigurationNeverFires() {
        for shortcut in [Shortcut(modifiers: []), Shortcut(modifiers: .shift),
                         Shortcut(modifiers: [.control, .function]), Shortcut(modifiers: .control, keyCode: 999)] {
            #expect(!shortcut.isValid)
            #expect(switches([flags(shortcut.modifiers), flags([])], shortcut: shortcut) == [])
        }
    }

    @Test func testShortcutSerializationAndPhysicalKeyName() throws {
        let shortcut = Shortcut(modifiers: [.control, .option], keyCode: 49)
        #expect(try JSONDecoder().decode(Shortcut.self, from: JSONEncoder().encode(shortcut)) == shortcut)
        #expect(shortcut.displayName == "⌃ ⌥ Space")
        #expect(Shortcut.default.displayName == "⌃ ⇧")
    }
}
