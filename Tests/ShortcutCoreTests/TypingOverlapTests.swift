import Testing
@testable import ShortcutCore

struct TypingOverlapTests {
    private let chord: Modifiers = [.control, .shift]
    private func flags(_ modifiers: Modifiers) -> ShortcutEvent { .init(.modifiersChanged, modifiers: modifiers) }
    private func down(_ code: UInt16, _ modifiers: Modifiers, repeat repeating: Bool = false) -> ShortcutEvent {
        .init(.keyDown(code, isRepeat: repeating), modifiers: modifiers)
    }
    private func up(_ code: UInt16, _ modifiers: Modifiers) -> ShortcutEvent { .init(.keyUp(code), modifiers: modifiers) }
    private func switches(_ events: [ShortcutEvent], shortcuts: [Shortcut] = [.default]) -> [Int] {
        var recognizer = ShortcutGroupRecognizer(shortcuts: shortcuts)
        return events.indices.filter { recognizer.handle(events[$0]) }
    }

    @Test func previousLetterCanBeReleasedBeforeOrAfterTheModifiers() {
        for first: Modifiers in [.control, .shift] {
            for remaining: Modifiers in [.control, .shift] {
                #expect(switches([down(0, []), flags(first), up(0, first), flags(chord),
                                 flags(remaining), flags([])]) == [4])
                #expect(switches([down(0, []), flags(first), flags(chord), up(0, chord),
                                 flags(remaining), flags([])]) == [4])
                #expect(switches([down(0, []), flags(first), flags(chord), flags(remaining),
                                 flags([]), up(0, [])]) == [3])
            }
        }
    }

    @Test func overlappingLettersFromTypingDoNotBlockEitherShortcut() {
        let alternative = Shortcut(modifiers: [.option, .shift])
        #expect(switches([down(0, []), down(1, []), flags(.control), up(0, .control),
                         flags(chord), flags([]), down(2, []), up(1, []),
                         flags(alternative.modifiers), up(2, alternative.modifiers), flags([])],
                        shortcuts: [.default, alternative]) == [5, 10])
    }

    @Test func shiftedTypingCanPrecedeTheShortcut() {
        for shortcut in [Shortcut.default, Shortcut(modifiers: [.option, .shift])] {
            #expect(switches([flags(.shift), down(0, .shift), flags(shortcut.modifiers),
                             up(0, shortcut.modifiers), flags(.shift), flags([])],
                            shortcuts: [shortcut]) == [4])
        }
        let noShift = Shortcut(modifiers: [.control, .option])
        #expect(switches([flags(.shift), down(0, .shift), flags([]), flags(noShift.modifiers),
                         up(0, noShift.modifiers), flags([])], shortcuts: [noShift]) == [5])
        #expect(switches([flags(.shift), down(0, .shift), flags(noShift.modifiers.union(.shift)),
                         up(0, noShift.modifiers.union(.shift)), flags([])], shortcuts: [noShift]) == [])
    }

    @Test func navigationKeysAreNotTreatedAsEarlierTyping() {
        for key: UInt16 in [36, 48, 53, 123, 124, 125, 126, 122] {
            for typingModifiers: Modifiers in [[], .shift] {
                #expect(switches([flags(typingModifiers), down(key, typingModifiers),
                                 flags(chord), up(key, chord), flags([])]) == [])
            }
        }
    }

    @Test func repeatBeforeShortcutModifiersIsStillPlainTyping() {
        #expect(switches([down(0, []), down(0, [], repeat: true), flags(chord),
                         up(0, chord), flags([])]) == [4])
    }

    @Test func newKeyDuringShortcutStillCancels() {
        for during: Modifiers in [.control, chord] {
            #expect(switches([down(0, []), flags(during), down(1, during), up(0, during),
                             up(1, during), flags(chord), flags([])]) == [])
        }
        #expect(switches([down(0, []), flags(chord), down(123, chord), up(0, chord),
                         up(123, chord), flags([])]) == [])
    }

    @Test func repeatingPreviousKeyWithShortcutModifiersCancels() {
        #expect(switches([down(0, []), flags(chord), down(0, chord, repeat: true),
                         flags([]), up(0, []), flags(chord), flags([])]) == [6])
    }

    @Test func unrelatedActionsDuringTypingStillBlockTheGesture() {
        let conflicts: [[ShortcutEvent]] = [
            [.init(.pointerDown(0), modifiers: []), .init(.pointerUp(0), modifiers: [])],
            [.init(.otherAction, modifiers: [])],
            [flags(.command), flags([])],
            [up(1, [])]
        ]
        for conflict in conflicts {
            let events = [down(0, [])] + conflict + [flags(chord), up(0, chord), flags([]),
                flags(chord), flags([])]
            #expect(switches(events) == [events.count - 1])
        }
    }

    @Test func ordinaryKeyShortcutAcceptsEarlierTypingButNeedsAFreshShortcutKey() {
        let shortcut = Shortcut(modifiers: .control, keyCode: 49)
        #expect(switches([down(0, []), flags(.control), down(49, .control),
                         up(0, .control), up(49, .control), flags([])], shortcuts: [shortcut]) == [4])
        #expect(switches([down(49, []), flags(.control), up(49, .control), flags([])],
                        shortcuts: [shortcut]) == [])
        #expect(switches([down(49, []), flags(.control), up(49, .control),
                         down(49, .control), up(49, .control), flags([])], shortcuts: [shortcut]) == [4])
        let shiftSpace = Shortcut(modifiers: .shift, keyCode: 49)
        #expect(switches([down(0, []), flags(.shift), down(49, .shift), up(0, .shift),
                         up(49, .shift), flags([])], shortcuts: [shiftSpace]) == [4])
        #expect(switches([flags(.shift), down(0, .shift), up(0, .shift), down(49, .shift),
                         up(49, .shift), flags([])], shortcuts: [shiftSpace]) == [])
    }

    @Test func largerShortcutWithEarlierTypingStillSwitchesOnlyOnce() {
        let shortcuts: [Shortcut] = [.default, Shortcut(modifiers: chord, keyCode: 49)]
        #expect(switches([down(0, []), flags(chord), down(49, chord), up(49, chord),
                         up(0, chord), flags(chord), flags(.shift), flags([])],
                        shortcuts: shortcuts) == [3])
    }

    @Test func resetDoesNotTreatPreviouslyHeldKeysAsTyping() {
        var recognizer = ShortcutGroupRecognizer(shortcuts: [.default])
        recognizer.reset(keysDown: [0])
        for event in [flags(chord), up(0, chord), flags([])] {
            #expect(recognizer.handle(event) == false)
        }
        #expect(recognizer.handle(flags(chord)) == false)
        #expect(recognizer.handle(flags([])) == true)
    }
}
