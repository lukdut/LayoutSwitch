import Foundation
import Testing
@testable import ShortcutCore

struct ShortcutCaptureTests {
    @Test func testRecordModifierOnlyChord() {
        var capture = ShortcutCapture()
        #expect(capture.handle(.init(.modifiersChanged, modifiers: .shift)) == .pending)
        #expect(capture.handle(.init(.modifiersChanged, modifiers: [.control, .shift])) == .pending)
        #expect(capture.handle(.init(.modifiersChanged, modifiers: .control)) == .pending)
        #expect(capture.handle(.init(.modifiersChanged, modifiers: [])) == .captured(.default))
    }

    @Test func testRecordKeyChordAndIgnoreRepeat() {
        var capture = ShortcutCapture()
        #expect(capture.handle(.init(.modifiersChanged, modifiers: .option)) == .pending)
        #expect(capture.handle(.init(.keyDown(49, isRepeat: false), modifiers: .option)) == .pending)
        #expect(capture.handle(.init(.keyDown(49, isRepeat: true), modifiers: .option)) == .pending)
        #expect(capture.handle(.init(.modifiersChanged, modifiers: [])) == .pending)
        #expect(capture.handle(.init(.keyUp(49), modifiers: [])) == .captured(Shortcut(modifiers: .option, keyCode: 49)))
    }

    @Test func testPlainKeyAndSingleModifierAreRejectedThenCanRetry() {
        var capture = ShortcutCapture()
        _ = capture.handle(.init(.keyDown(0, isRepeat: false), modifiers: []))
        #expect(capture.handle(.init(.keyUp(0), modifiers: [])) == .rejected)
        _ = capture.handle(.init(.modifiersChanged, modifiers: .control))
        #expect(capture.handle(.init(.modifiersChanged, modifiers: [])) == .rejected)
        _ = capture.handle(.init(.modifiersChanged, modifiers: [.control, .shift]))
        #expect(capture.handle(.init(.modifiersChanged, modifiers: [])) == .captured(.default))
    }

    @Test func testMultipleOrdinaryKeysAreRejected() {
        var capture = ShortcutCapture()
        _ = capture.handle(.init(.modifiersChanged, modifiers: .control))
        _ = capture.handle(.init(.keyDown(0, isRepeat: false), modifiers: .control))
        _ = capture.handle(.init(.keyDown(1, isRepeat: false), modifiers: .control))
        _ = capture.handle(.init(.keyUp(0), modifiers: .control))
        _ = capture.handle(.init(.keyUp(1), modifiers: .control))
        #expect(capture.handle(.init(.modifiersChanged, modifiers: [])) == .rejected)
    }

    @Test func testModifierRepressIsRejected() {
        var capture = ShortcutCapture()
        _ = capture.handle(.init(.modifiersChanged, modifiers: [.control, .shift]))
        _ = capture.handle(.init(.modifiersChanged, modifiers: .control))
        _ = capture.handle(.init(.modifiersChanged, modifiers: [.control, .option]))
        #expect(capture.handle(.init(.modifiersChanged, modifiers: [])) == .rejected)
    }

    @Test func testModifierAddedAfterOrdinaryKeyIsRejected() {
        var capture = ShortcutCapture()
        _ = capture.handle(.init(.modifiersChanged, modifiers: .control))
        _ = capture.handle(.init(.keyDown(0, isRepeat: false), modifiers: .control))
        _ = capture.handle(.init(.modifiersChanged, modifiers: [.control, .shift]))
        _ = capture.handle(.init(.keyUp(0), modifiers: [.control, .shift]))
        #expect(capture.handle(.init(.modifiersChanged, modifiers: [])) == .rejected)
    }

    @Test func testEscapeCancelsAndModifiedEscapeCanBeRecorded() {
        var capture = ShortcutCapture()
        #expect(capture.handle(.init(.keyDown(53, isRepeat: false), modifiers: [])) == .cancelled)
        _ = capture.handle(.init(.modifiersChanged, modifiers: .option))
        _ = capture.handle(.init(.keyDown(53, isRepeat: false), modifiers: .option))
        _ = capture.handle(.init(.keyUp(53), modifiers: .option))
        #expect(capture.handle(.init(.modifiersChanged, modifiers: [])) == .captured(Shortcut(modifiers: .option, keyCode: 53)))
    }
}
