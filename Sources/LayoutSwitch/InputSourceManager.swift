import AppKit
import Carbon
import ShortcutCore

struct InputSource: Identifiable, Equatable {
    let id: String
    let name: String
    let language: String
    let isInputMethod: Bool
    var badge: String { String(language.prefix(2)).uppercased() }
}

struct InputSourceSelectionTimings {
    enum Outcome: String {
        case unavailable, failed, confirmed, unconfirmed
    }

    var outcome: Outcome = .unavailable
    var statusCode: OSStatus?
    var readCurrentMS = 0.0
    var prepareMS = 0.0
    var selectMS = 0.0
    var confirmMS = 0.0
}

@MainActor
protocol InputSourceBackend {
    func loadSources() -> [InputSource]
    func currentSourceID() -> String?
    func isSelectable(_ id: String) -> Bool
    func select(_ id: String) -> OSStatus
}

@MainActor
private final class SystemInputSourceBackend: InputSourceBackend {
    private var handles: [String: TISInputSource] = [:]

    func loadSources() -> [InputSource] {
        let filter = [
            kTISPropertyInputSourceCategory as String: kTISCategoryKeyboardInputSource as String,
            kTISPropertyInputSourceIsSelectCapable as String: true,
        ] as [String: Any]
        let raw = TISCreateInputSourceList(filter as CFDictionary, false)?.takeRetainedValue()
        let inputSources = (raw as? [TISInputSource]) ?? []
        var sources: [InputSource] = []
        var handles: [String: TISInputSource] = [:]
        for source in inputSources {
            guard let id = property(source, kTISPropertyInputSourceID) as? String,
                  let name = property(source, kTISPropertyLocalizedName) as? String,
                  property(source, kTISPropertyInputSourceIsEnabled) as? Bool == true,
                  handles[id] == nil else { continue }
            let language = (property(source, kTISPropertyInputSourceLanguages) as? [String])?.first ?? "??"
            let type = property(source, kTISPropertyInputSourceType) as? String
            sources.append(InputSource(id: id, name: name, language: language,
                                       isInputMethod: type != kTISTypeKeyboardLayout as String))
            handles[id] = source
        }
        self.handles = handles
        return sources
    }

    func currentSourceID() -> String? {
        guard let source = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue() else { return nil }
        return property(source, kTISPropertyInputSourceID) as? String
    }

    func isSelectable(_ id: String) -> Bool {
        guard let source = handles[id] else { return false }
        return property(source, kTISPropertyInputSourceIsEnabled) as? Bool == true &&
            property(source, kTISPropertyInputSourceIsSelectCapable) as? Bool == true
    }

    func select(_ id: String) -> OSStatus {
        guard let source = handles[id], isSelectable(id) else { return OSStatus(paramErr) }
        return TISSelectInputSource(source)
    }

    private func property(_ source: TISInputSource, _ key: CFString) -> AnyObject? {
        guard let pointer = TISGetInputSourceProperty(source, key) else { return nil }
        return Unmanaged<AnyObject>.fromOpaque(pointer).takeUnretainedValue()
    }
}

@MainActor
final class InputSourceManager {
    private(set) var sources: [InputSource] = []
    private(set) var currentID: String?
    private(set) var lastSelectionTimings = InputSourceSelectionTimings()
    private let backend: any InputSourceBackend
    var current: InputSource? { sources.first { $0.id == currentID } }

    init(backend: (any InputSourceBackend)? = nil) {
        self.backend = backend ?? SystemInputSourceBackend()
    }

    func refresh() {
        sources = backend.loadSources()
        refreshCurrent()
    }

    func refreshCurrent() {
        currentID = backend.currentSourceID()
    }

    func selectNext(selectedIDs: [String]?) -> String? {
        var timings = InputSourceSelectionTimings()
        defer { lastSelectionTimings = timings }
        let startedAt = DispatchTime.now().uptimeNanoseconds
        // Read the actual current source: macOS or another app may have changed
        // it before its notification reached us. Reuse the cached source list.
        refreshCurrent()
        let readAt = DispatchTime.now().uptimeNanoseconds
        timings.readCurrentMS = Double(readAt - startedAt) / 1_000_000
        let candidates = InputSourceCycle.candidates(available: sources.map(\.id), selected: selectedIDs)
        if candidates.count < 2 || candidates.contains(where: { !backend.isSelectable($0) }) {
            // Recover if enabled sources changed before their notification arrived.
            refresh()
        }
        let nextID = InputSourceCycle.next(available: sources.map(\.id), selected: selectedIDs,
                                          current: currentID)
        let preparedAt = DispatchTime.now().uptimeNanoseconds
        timings.prepareMS = Double(preparedAt - readAt) / 1_000_000
        guard let nextID else {
            return "Выберите хотя бы две доступные раскладки."
        }
        let status = backend.select(nextID)
        timings.statusCode = status
        let selectedAt = DispatchTime.now().uptimeNanoseconds
        timings.selectMS = Double(selectedAt - preparedAt) / 1_000_000
        defer {
            timings.confirmMS = Double(DispatchTime.now().uptimeNanoseconds - selectedAt) / 1_000_000
        }
        guard status == noErr else {
            timings.outcome = .failed
            // The source may have disappeared after validation. Discard stale
            // handles so the next attempt uses the latest enabled sources.
            refresh()
            return "macOS не удалось переключить раскладку (код \(status))."
        }
        refreshCurrent()
        timings.outcome = currentID == nextID ? .confirmed : .unconfirmed
        return nil
    }
}
