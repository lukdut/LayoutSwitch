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

@MainActor
final class InputSourceManager {
    private(set) var sources: [InputSource] = []
    private(set) var currentID: String?
    private var handles: [String: TISInputSource] = [:]
    var current: InputSource? { sources.first { $0.id == currentID } }

    func refresh() {
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
        self.sources = sources
        self.handles = handles
        refreshCurrent()
    }

    func refreshCurrent() {
        guard let source = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue() else {
            currentID = nil
            return
        }
        currentID = property(source, kTISPropertyInputSourceID) as? String
    }

    func selectNext(selectedIDs: [String]?) -> String? {
        // TIS lists are snapshots; refresh before selecting a possibly removed source.
        refresh()
        guard let nextID = InputSourceCycle.next(available: sources.map(\.id), selected: selectedIDs,
                                                current: currentID),
              let source = handles[nextID] else {
            return "Выберите хотя бы две доступные раскладки."
        }
        let status = TISSelectInputSource(source)
        guard status == noErr else {
            return "macOS не удалось переключить раскладку (код \(status))."
        }
        refreshCurrent()
        return nil
    }

    private func property(_ source: TISInputSource, _ key: CFString) -> AnyObject? {
        guard let pointer = TISGetInputSourceProperty(source, key) else { return nil }
        return Unmanaged<AnyObject>.fromOpaque(pointer).takeUnretainedValue()
    }
}
