import Carbon
import Testing
@testable import LayoutSwitch

@MainActor
struct InputSourceManagerTests {
    private func source(_ id: String) -> InputSource {
        InputSource(id: id, name: id, language: id, isInputMethod: false)
    }

    @Test func repeatedSwitchesReuseTheSourceList() {
        let backend = FakeInputSourceBackend(sources: [source("en"), source("ru")], currentID: "en")
        let manager = InputSourceManager(backend: backend)
        manager.refresh()

        #expect(manager.selectNext(selectedIDs: nil) == nil)
        #expect(manager.currentID == "ru")
        #expect(manager.selectNext(selectedIDs: nil) == nil)
        #expect(manager.currentID == "en")
        #expect(backend.selections == ["ru", "en"])
        #expect(backend.loadCount == 1)
    }

    @Test func firstSwitchLoadsSourcesIfNeeded() {
        let backend = FakeInputSourceBackend(sources: [source("en"), source("ru")], currentID: "en")
        let manager = InputSourceManager(backend: backend)

        #expect(manager.selectNext(selectedIDs: nil) == nil)
        #expect(manager.currentID == "ru")
        #expect(backend.loadCount == 1)
    }

    @Test func externalSwitchIsReadBeforeItsNotificationArrives() {
        let backend = FakeInputSourceBackend(sources: [source("en"), source("ru"), source("de")],
                                             currentID: "en")
        let manager = InputSourceManager(backend: backend)
        manager.refresh()
        backend.currentID = "ru"

        #expect(manager.selectNext(selectedIDs: nil) == nil)
        #expect(backend.selections == ["de"])
        #expect(manager.currentID == "de")
        #expect(backend.loadCount == 1)
    }

    @Test func currentSourceRefreshDoesNotReloadTheList() {
        let backend = FakeInputSourceBackend(sources: [source("en"), source("ru")], currentID: "en")
        let manager = InputSourceManager(backend: backend)
        manager.refresh()
        backend.currentID = "ru"
        manager.refreshCurrent()

        #expect(manager.current == source("ru"))
        #expect(backend.loadCount == 1)
        #expect(backend.selections.isEmpty)
    }

    @Test func removedSourceIsSkippedBeforeTheListNotificationArrives() {
        let backend = FakeInputSourceBackend(sources: [source("en"), source("ru"), source("de")],
                                             currentID: "en")
        let manager = InputSourceManager(backend: backend)
        manager.refresh()
        backend.sources.removeAll { $0.id == "ru" }

        #expect(manager.selectNext(selectedIDs: nil) == nil)
        #expect(backend.selections == ["de"])
        #expect(manager.sources.map(\.id) == ["en", "de"])
        #expect(backend.loadCount == 2)
    }

    @Test func removedCheckedSourceDoesNotFallBackToAnUncheckedSource() {
        let backend = FakeInputSourceBackend(sources: [source("en"), source("ru"), source("de")],
                                             currentID: "en")
        let manager = InputSourceManager(backend: backend)
        manager.refresh()
        backend.sources.removeAll { $0.id == "ru" }

        #expect(manager.selectNext(selectedIDs: ["en", "ru"]) != nil)
        #expect(backend.selections.isEmpty)
        #expect(manager.currentID == "en")
        #expect(manager.sources.map(\.id) == ["en", "de"])
    }

    @Test func newlyEnabledSourceRecoversAnInsufficientCachedList() {
        let backend = FakeInputSourceBackend(sources: [source("en")], currentID: "en")
        let manager = InputSourceManager(backend: backend)
        manager.refresh()
        backend.sources.append(source("ru"))

        #expect(manager.selectNext(selectedIDs: nil) == nil)
        #expect(backend.selections == ["ru"])
        #expect(backend.loadCount == 2)
    }

    @Test func refreshedListIncludesNewSourcesInTheCycle() {
        let backend = FakeInputSourceBackend(sources: [source("en"), source("ru")], currentID: "ru")
        let manager = InputSourceManager(backend: backend)
        manager.refresh()
        backend.sources.append(source("de"))
        manager.refresh()

        #expect(manager.selectNext(selectedIDs: nil) == nil)
        #expect(backend.selections == ["de"])
        #expect(backend.loadCount == 2)
    }

    @Test func selectionFailureRefreshesTheCacheAndDoesNotSwitchTwice() {
        let backend = FakeInputSourceBackend(sources: [source("en"), source("ru")], currentID: "en")
        let manager = InputSourceManager(backend: backend)
        manager.refresh()
        backend.selectionStatus = OSStatus(paramErr)

        #expect(manager.selectNext(selectedIDs: nil)?.contains("-50") == true)
        #expect(backend.loadCount == 2)
        #expect(backend.selections == ["ru"])
        #expect(manager.currentID == "en")

        backend.selectionStatus = noErr
        #expect(manager.selectNext(selectedIDs: nil) == nil)
        #expect(manager.currentID == "ru")
        #expect(backend.loadCount == 2)
    }

    @Test func emptyOrSingleSelectionNeverSwitches() {
        let backend = FakeInputSourceBackend(sources: [source("en"), source("ru")], currentID: "en")
        let manager = InputSourceManager(backend: backend)
        manager.refresh()

        for selected: [String] in [[], ["en"], ["en", "en"], ["missing", "en"]] {
            #expect(manager.selectNext(selectedIDs: selected) != nil)
        }
        #expect(backend.selections.isEmpty)
        #expect(manager.currentID == "en")
    }
}

@MainActor
private final class FakeInputSourceBackend: InputSourceBackend {
    var sources: [InputSource]
    var currentID: String?
    var selectionStatus: OSStatus = noErr
    private(set) var loadCount = 0
    private(set) var selections: [String] = []

    init(sources: [InputSource], currentID: String?) {
        self.sources = sources
        self.currentID = currentID
    }

    func loadSources() -> [InputSource] {
        loadCount += 1
        return sources
    }

    func currentSourceID() -> String? { currentID }
    func isSelectable(_ id: String) -> Bool { sources.contains { $0.id == id } }

    func select(_ id: String) -> OSStatus {
        selections.append(id)
        guard selectionStatus == noErr else { return selectionStatus }
        guard isSelectable(id) else { return OSStatus(paramErr) }
        currentID = id
        return noErr
    }
}
