import Testing
@testable import ShortcutCore

struct DeleteOverlapTests {
    private let shortcuts = [Shortcut.default, Shortcut(modifiers: [.option, .shift])]
    private let backspace: UInt16 = 51
    private let forwardDelete: UInt16 = 117

    private func flags(_ modifiers: Modifiers) -> ShortcutEvent {
        .init(.modifiersChanged, modifiers: modifiers)
    }

    private func down(_ code: UInt16, _ modifiers: Modifiers, repeat repeating: Bool = false) -> ShortcutEvent {
        .init(.keyDown(code, isRepeat: repeating), modifiers: modifiers)
    }

    private func up(_ code: UInt16, _ modifiers: Modifiers) -> ShortcutEvent {
        .init(.keyUp(code), modifiers: modifiers)
    }

    private func result(_ events: [ShortcutEvent], shortcut: Shortcut) -> (
        switches: [Int], cancellations: [Int: [ShortcutRecognizer.CancellationReason]]
    ) {
        var recognizer = ShortcutGroupRecognizer(shortcuts: [shortcut])
        var switches: [Int] = []
        var cancellations: [Int: [ShortcutRecognizer.CancellationReason]] = [:]
        for (index, event) in events.enumerated() {
            if recognizer.handle(event) { switches.append(index) }
            if !recognizer.lastCancellationReasons.isEmpty {
                cancellations[index] = recognizer.lastCancellationReasons
            }
        }
        return (switches, cancellations)
    }

    @Test func backspaceRepeatingBeforeShortcutModifiersDoesNotBlockSwitching() {
        for shortcut in shortcuts {
            for typingModifiers: Modifiers in [[], .shift] {
                let observed = result([
                    flags(typingModifiers), down(backspace, typingModifiers),
                    down(backspace, typingModifiers, repeat: true),
                    down(backspace, typingModifiers, repeat: true),
                    flags(shortcut.modifiers), up(backspace, shortcut.modifiers),
                    flags(.shift), flags([])
                ], shortcut: shortcut)
                #expect(observed.switches == [6])
                #expect(observed.cancellations.isEmpty)
            }
        }
    }

    @Test func backspaceReleasedBeforeShortcutDoesNotLeaveRepeatStateBehind() {
        for shortcut in shortcuts {
            let observed = result([
                down(backspace, []), down(backspace, [], repeat: true),
                down(backspace, [], repeat: true), up(backspace, []),
                flags(shortcut.modifiers), flags(.shift), flags([])
            ], shortcut: shortcut)
            #expect(observed.switches == [5])
            #expect(observed.cancellations.isEmpty)
        }
    }

    @Test func precedingBackspaceRepeatAfterControlOrOptionAllowsSwitching() {
        for shortcut in shortcuts {
            let firstModifier = shortcut.modifiers.subtracting(.shift)
            let observed = result([
                down(backspace, []), down(backspace, [], repeat: true),
                flags(firstModifier), down(backspace, firstModifier, repeat: true),
                up(backspace, firstModifier), flags(shortcut.modifiers),
                flags(.shift), flags([])
            ], shortcut: shortcut)
            #expect(observed.switches == [6])
            #expect(observed.cancellations.isEmpty)
        }
    }

    @Test func precedingBackspaceRepeatDuringCompleteChordAllowsSwitching() {
        for shortcut in shortcuts {
            let observed = result([
                down(backspace, []), flags(shortcut.modifiers),
                down(backspace, shortcut.modifiers, repeat: true),
                up(backspace, shortcut.modifiers), flags(.shift), flags([])
            ], shortcut: shortcut)
            #expect(observed.switches == [4])
            #expect(observed.cancellations.isEmpty)
        }
    }

    @Test func markerThreeBackspaceRepeatsBetweenControlAndShiftStillSwitch() {
        // The diagnostic trace before marker 3: seq83040...83047. Delete was
        // already held, then repeated three times after Ctrl and before Shift.
        let observed = result([
            down(backspace, []), flags(.control),
            down(backspace, .control, repeat: true),
            down(backspace, .control, repeat: true),
            down(backspace, .control, repeat: true),
            flags(Shortcut.default.modifiers), up(backspace, Shortcut.default.modifiers),
            flags(.shift), flags([])
        ], shortcut: .default)
        #expect(observed.switches == [7])
        #expect(observed.cancellations.isEmpty)
    }

    @Test func cancelledBackspaceOverlapCanRetryAfterAllModifiersAreReleased() {
        for shortcut in shortcuts {
            let observed = result([
                down(backspace, []), flags(shortcut.modifiers),
                down(123, shortcut.modifiers), up(123, shortcut.modifiers),
                // An allowed repeat must not clear a genuine conflicting action.
                down(backspace, shortcut.modifiers, repeat: true), flags(.shift),
                // Keeping Shift must not clear cancellation from the first attempt.
                flags(shortcut.modifiers), flags(.shift), flags([]),
                // The old Delete is still down, but its unmodified repeat is typing again.
                down(backspace, [], repeat: true), flags(shortcut.modifiers),
                flags(.shift), flags([]), up(backspace, [])
            ], shortcut: shortcut)
            #expect(observed.switches == [11])
            #expect(observed.cancellations == [5: [.otherKey], 7: [.otherKey]])
        }
    }

    @Test func freshModifiedDeleteActionStillCancelsLayoutShortcut() {
        for shortcut in shortcuts {
            let firstModifier = shortcut.modifiers.subtracting(.shift)
            for code in [backspace, forwardDelete] {
                for heldModifiers in [firstModifier, shortcut.modifiers] {
                    let observed = result([
                        flags(heldModifiers), down(code, heldModifiers),
                        down(code, heldModifiers, repeat: true), up(code, heldModifiers),
                        flags(shortcut.modifiers), flags(.shift), flags([])
                    ], shortcut: shortcut)
                    #expect(observed.switches.isEmpty)
                    #expect(observed.cancellations == [5: [.otherKey]])
                }
            }
        }
    }

    @Test func releasingAndPressingTheOldBackspaceAgainIsANewModifiedAction() {
        for shortcut in shortcuts {
            let firstModifier = shortcut.modifiers.subtracting(.shift)
            let observed = result([
                down(backspace, []), flags(firstModifier), up(backspace, firstModifier),
                down(backspace, firstModifier), down(backspace, firstModifier, repeat: true),
                flags(shortcut.modifiers), up(backspace, shortcut.modifiers), flags(.shift), flags([])
            ], shortcut: shortcut)
            #expect(observed.switches.isEmpty)
            #expect(observed.cancellations == [7: [.otherKey]])
        }
    }

    @Test func precedingBackspaceRepeatsAfterSwitchDoNotSwitchAgain() {
        for shortcut in shortcuts {
            for remaining in [Modifiers.shift, shortcut.modifiers.subtracting(.shift)] {
                let observed = result([
                    down(backspace, []), flags(shortcut.modifiers),
                    down(backspace, shortcut.modifiers, repeat: true), flags(remaining),
                    down(backspace, remaining, repeat: true), down(backspace, remaining, repeat: true),
                    up(backspace, remaining), flags([])
                ], shortcut: shortcut)
                #expect(observed.switches == [3])
                #expect(observed.cancellations.isEmpty)
            }
        }
    }

    @Test func precedingBackspaceCannotBecomeTheShortcutsOwnKeyThroughRepeats() {
        let shortcut = Shortcut(modifiers: .control, keyCode: backspace)
        let observed = result([
            down(backspace, []), flags(.control), down(backspace, .control, repeat: true),
            up(backspace, .control), flags([]),
            flags(.control), down(backspace, .control), down(backspace, .control, repeat: true),
            up(backspace, .control), flags([])
        ], shortcut: shortcut)
        #expect(observed.switches == [8])
        #expect(observed.cancellations.isEmpty)
    }

    @Test func backspaceAlreadyHeldAtResetIsNotAcceptedAsPrecedingTyping() {
        var recognizer = ShortcutGroupRecognizer(shortcuts: shortcuts)
        recognizer.reset(keysDown: [backspace])
        for event in [flags(Shortcut.default.modifiers),
                      down(backspace, Shortcut.default.modifiers, repeat: true)] {
            #expect(recognizer.handle(event) == false)
        }
        #expect(recognizer.handle(flags(.shift)) == false)
        #expect(recognizer.lastCancellationReasons == [.heldAtReset])
        #expect(recognizer.handle(up(backspace, .shift)) == false)
        #expect(recognizer.handle(flags([])) == false)
        #expect(recognizer.handle(flags(Shortcut.default.modifiers)) == false)
        #expect(recognizer.handle(flags(.shift)) == true)
        #expect(recognizer.lastCancellationReasons.isEmpty)
    }

    @Test func forwardDeleteIsNotTreatedAsPrecedingTyping() {
        for shortcut in shortcuts {
            let observed = result([
                down(forwardDelete, []), down(forwardDelete, [], repeat: true),
                flags(shortcut.modifiers), up(forwardDelete, shortcut.modifiers),
                flags(.shift), flags([]), flags(shortcut.modifiers), flags(.shift), flags([])
            ], shortcut: shortcut)
            #expect(observed.switches == [7])
            #expect(observed.cancellations == [4: [.otherKey]])
        }
    }

    @Test func functionDeleteMustBeReleasedBeforeANewShortcutGesture() {
        for shortcut in shortcuts {
            // Cover either delivered Delete code; hardware translation is outside ShortcutCore.
            for code in [backspace, forwardDelete] {
                let chordWithFunction = shortcut.modifiers.union(.function)
                let observed = result([
                    flags(.function), down(code, .function), down(code, .function, repeat: true),
                    flags(chordWithFunction), up(code, chordWithFunction),
                    flags(shortcut.modifiers), flags(.shift), flags([]),
                    flags(shortcut.modifiers), flags(.shift), flags([])
                ], shortcut: shortcut)
                #expect(observed.switches == [9])
                #expect(observed.cancellations == [6: [.extraModifier]])
            }
        }
    }
}
