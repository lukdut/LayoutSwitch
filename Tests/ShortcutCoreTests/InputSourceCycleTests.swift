import Foundation
import Testing
@testable import ShortcutCore

struct InputSourceCycleTests {
    @Test func testCyclesAndWrapsAllSources() {
        #expect(InputSourceCycle.next(available: ["en", "ru", "de"], selected: nil, current: "en") == "ru")
        #expect(InputSourceCycle.next(available: ["en", "ru", "de"], selected: nil, current: "de") == "en")
    }

    @Test func testChosenOrderAndUnknownCurrentSource() {
        #expect(InputSourceCycle.next(available: ["en", "ru", "de"], selected: ["de", "en"], current: "de") == "en")
        #expect(InputSourceCycle.next(available: ["en", "ru", "de"], selected: ["de", "en"], current: "ru") == "de")
        #expect(InputSourceCycle.next(available: ["en", "ru"], selected: nil, current: nil) == "en")
    }

    @Test func testRemovedSourcesAndDuplicatesAreSkipped() {
        #expect(InputSourceCycle.candidates(available: ["en", "ru"], selected: ["de", "ru", "ru", "en"]) == ["ru", "en"])
        #expect(InputSourceCycle.next(available: ["en", "ru"], selected: ["de", "ru", "en"], current: "ru") == "en")
    }

    @Test func testEmptyAndSingleSelectionsNeverFallBackToOtherSources() {
        for selected: [String] in [[], ["en"], ["en", "en"], ["removed"], ["removed", "en"]] {
            #expect(InputSourceCycle.next(available: ["en", "ru"], selected: selected, current: "en") == nil)
        }
        #expect(InputSourceCycle.next(available: [], selected: nil, current: nil) == nil)
        #expect(InputSourceCycle.next(available: ["en"], selected: nil, current: "en") == nil)
    }

    @Test func testNewSourcesOnlyJoinAutomaticSelection() {
        #expect(InputSourceCycle.candidates(available: ["en", "ru", "de"], selected: nil) == ["en", "ru", "de"])
        #expect(InputSourceCycle.candidates(available: ["en", "ru", "de"], selected: ["en", "ru"]) == ["en", "ru"])
    }
}
