import Testing
@testable import ShortcutCore

struct ShortcutGroupRecognizerTests {
    private let chord: Modifiers = [.control, .shift]
    private func flags(_ modifiers: Modifiers) -> ShortcutEvent { .init(.modifiersChanged, modifiers: modifiers) }
    private func down(_ code: UInt16, _ modifiers: Modifiers) -> ShortcutEvent {
        .init(.keyDown(code, isRepeat: false), modifiers: modifiers)
    }
    private func up(_ code: UInt16, _ modifiers: Modifiers) -> ShortcutEvent { .init(.keyUp(code), modifiers: modifiers) }
    private func switches(_ events: [ShortcutEvent], _ shortcuts: [Shortcut]) -> [Int] {
        var recognizer = ShortcutGroupRecognizer(shortcuts: shortcuts)
        return events.indices.filter { recognizer.handle(events[$0]) }
    }

    @Test func alternativesCanShareHeldModifier() {
        let alt: Modifiers = [.option, .shift]
        #expect(switches([flags(chord), flags(.shift), flags(alt), flags(.shift),
                         flags(chord), flags(.shift), flags([])],
                        [.default, Shortcut(modifiers: alt)]) == [1, 3, 5])
    }

    @Test func regularKeyAlternativesCanShareHeldModifier() {
        let shortcuts = [49, 40].map { Shortcut(modifiers: .control, keyCode: UInt16($0)) }
        #expect(switches([flags(.control), down(49, .control), up(49, .control),
                         down(40, .control), up(40, .control), down(49, .control),
                         up(49, .control), flags([])], shortcuts) == [2, 4, 6])
    }

    @Test func overlappingModifierChordsDoNotDoubleSwitch() {
        let larger = chord.union(.option)
        for first: Modifiers in [.control, .shift, .option] {
            for remaining: Modifiers in [chord, [.control, .option], [.shift, .option]] {
                #expect(switches([flags(first), flags(larger), flags(remaining),
                                 flags(remaining), flags(.control), flags([]),
                                 flags(chord), flags([])],
                                [.default, Shortcut(modifiers: larger)]) == [2, 7])
            }
        }
    }

    @Test func regularKeyOverlapDoesNotArmInheritedModifierChord() {
        let shortcuts: [Shortcut] = [.default, Shortcut(modifiers: chord, keyCode: 49)]
        #expect(switches([flags(chord), down(49, chord), up(49, chord), flags(chord),
                         flags(.shift), flags(chord), flags(.shift), flags([])], shortcuts) == [2, 6])
        #expect(switches([flags(chord), down(49, chord), flags(.shift), up(49, .shift),
                         flags([]), flags(chord), flags([])], shortcuts) == [2, 6])
    }

    @Test func repeatAndRepeatedPressesWithSharedModifiers() {
        let shortcuts: [Shortcut] = [.default, Shortcut(modifiers: chord, keyCode: 49)]
        #expect(switches([flags(chord), down(49, chord),
                         .init(.keyDown(49, isRepeat: true), modifiers: chord),
                         up(49, chord), down(49, chord), up(49, chord), flags([])], shortcuts) == [3, 5])
    }

    @Test func conflictsCancelUntilEverythingReleased() {
        let shortcuts: [Shortcut] = [.default, Shortcut(modifiers: .control, keyCode: 49)]
        let conflicts: [[ShortcutEvent]] = [
            [down(0, chord), up(0, chord)],
            [.init(.pointerDown(0), modifiers: chord), .init(.pointerUp(0), modifiers: chord)],
            [.init(.otherAction, modifiers: chord)],
            [flags(chord.union(.command)), flags(chord)]
        ]
        for conflict in conflicts {
            let events = [flags(chord)] + conflict + [flags(.control), down(49, .control),
                up(49, .control), flags([]), flags(chord), flags([])]
            #expect(switches(events, shortcuts) == [events.count - 1])
        }
    }

    @Test func resetWithHeldKeysRequiresRelease() {
        var recognizer = ShortcutGroupRecognizer(shortcuts: [.default, Shortcut(modifiers: chord, keyCode: 49)])
        recognizer.reset(modifiers: chord, keysDown: [49])
        #expect(recognizer.handle(up(49, chord)) == false)
        #expect(recognizer.handle(flags([])) == false)
        #expect(recognizer.handle(flags(chord)) == false)
        #expect(recognizer.handle(flags([])) == true)
    }

    @Test func duplicatesAndInvalidShortcutsAreIgnored() {
        let events = [flags(chord), flags([])]
        #expect(switches(events, [.default, .default, Shortcut(modifiers: [])]) == [1])
        #expect(switches(events, []) == [])
    }

    @Test func successfulAlternativeClearsSiblingCancellationDiagnostics() {
        var recognizer = ShortcutGroupRecognizer(shortcuts: [.default, Shortcut(modifiers: chord, keyCode: 49)])
        recognizer.handle(flags(chord))
        recognizer.handle(down(49, chord))
        #expect(recognizer.handle(up(49, chord)) == true)
        #expect(recognizer.lastCancellationReasons.isEmpty)
    }
}
