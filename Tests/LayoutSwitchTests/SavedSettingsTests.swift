import Foundation
import Testing
import ShortcutCore
@testable import LayoutSwitch

struct SavedSettingsTests {
    private let alternative = Shortcut(modifiers: [.option, .shift])
    private func decode(_ json: String) throws -> SavedSettings {
        try JSONDecoder().decode(SavedSettings.self, from: Data(json.utf8))
    }

    @Test func migratesLegacyShortcutAndPreservesOtherSettings() throws {
        let saved = try decode(#"{"shortcut":{"modifiers":6},"enabled":false,"selectedSourceIDs":["en","ru"]}"#)
        #expect(saved.shortcuts == [alternative])
        #expect(!saved.enabled)
        #expect(saved.selectedSourceIDs == ["en", "ru"])
    }

    @Test func newListTakesPriorityAndPreservesOrder() throws {
        let saved = try decode(#"{"shortcut":{"modifiers":3},"shortcuts":[{"modifiers":6},{"modifiers":1,"keyCode":49},{"modifiers":6},{"modifiers":0}]}"#)
        #expect(saved.shortcuts == [alternative, Shortcut(modifiers: .control, keyCode: 49)])
    }

    @Test func missingEmptyOrInvalidListUsesDefault() throws {
        for json in [#"{}"#, #"{"shortcuts":[]}"#, #"{"shortcut":{"modifiers":0}}"#,
                     #"{"shortcuts":[{"modifiers":16}]}"#] {
            #expect(try decode(json).shortcuts == [.default])
        }
    }

    @Test func roundTripAndRollbackPreserveSettings() throws {
        struct Legacy: Decodable { let shortcut: Shortcut; let enabled: Bool; let selectedSourceIDs: [String]? }
        for sources: [String]? in [nil, [], ["en", "ru"]] {
            let original = SavedSettings(shortcuts: [alternative, .default], enabled: false, selectedSourceIDs: sources)
            let data = try JSONEncoder().encode(original)
            let restored = try JSONDecoder().decode(SavedSettings.self, from: data)
            #expect(restored.shortcuts == original.shortcuts)
            #expect(restored.enabled == original.enabled)
            #expect(restored.selectedSourceIDs == sources)
            let legacy = try JSONDecoder().decode(Legacy.self, from: data)
            #expect(legacy.shortcut == alternative)
            #expect(!legacy.enabled)
            #expect(legacy.selectedSourceIDs == sources)
        }
    }

    @Test func addEditAndRemoveKeepAtLeastOneUniqueShortcut() {
        var saved = SavedSettings()
        #expect(saved.removeShortcut(.default) == false)
        #expect(saved.setShortcut(alternative) == nil)
        #expect(saved.setShortcut(alternative) == .duplicate)
        #expect(saved.setShortcut(alternative, replacing: .default) == .duplicate)
        #expect(saved.setShortcut(.default, replacing: .default) == nil)
        #expect(saved.setShortcut(Shortcut(modifiers: [])) == .invalid)
        #expect(saved.shortcuts == [.default, alternative])
        let third = Shortcut(modifiers: .control, keyCode: 49)
        #expect(saved.setShortcut(third, replacing: .default) == nil)
        #expect(saved.shortcuts == [third, alternative])
        #expect(saved.setShortcut(.default, replacing: .default) == .missing)
        #expect(saved.removeShortcut(.default) == false)
        #expect(saved.removeShortcut(third) == true)
        #expect(saved.removeShortcut(alternative) == false)
        #expect(saved.shortcuts == [alternative])
    }

    @Test func resetPreservesOtherSettings() {
        var saved = SavedSettings(shortcuts: [alternative], enabled: false, selectedSourceIDs: [])
        saved.restoreDefaultShortcut()
        #expect(saved.shortcuts == [.default])
        #expect(!saved.enabled)
        #expect(saved.selectedSourceIDs == [])
    }
}
