import Foundation
import ShortcutCore

struct SavedSettings: Codable {
    enum ShortcutError: Error, Equatable {
        case invalid, duplicate, missing
    }

    private(set) var shortcuts: [Shortcut]
    var enabled: Bool
    var selectedSourceIDs: [String]?

    init(shortcuts: [Shortcut] = [.default], enabled: Bool = true, selectedSourceIDs: [String]? = nil) {
        let valid = Shortcut.normalized(shortcuts)
        self.shortcuts = valid.isEmpty ? [.default] : valid
        self.enabled = enabled
        self.selectedSourceIDs = selectedSourceIDs
    }

    private enum CodingKeys: String, CodingKey {
        case shortcut, shortcuts, enabled, selectedSourceIDs
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        let shortcuts: [Shortcut]
        if let saved = try values.decodeIfPresent([Shortcut].self, forKey: .shortcuts) {
            shortcuts = saved
        } else {
            shortcuts = [try values.decodeIfPresent(Shortcut.self, forKey: .shortcut) ?? .default]
        }
        self.init(shortcuts: shortcuts,
                  enabled: try values.decodeIfPresent(Bool.self, forKey: .enabled) ?? true,
                  selectedSourceIDs: try values.decodeIfPresent([String].self, forKey: .selectedSourceIDs))
    }

    func encode(to encoder: Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(shortcuts, forKey: .shortcuts)
        // Older versions can still read the first shortcut if the user rolls back.
        try values.encode(shortcuts[0], forKey: .shortcut)
        try values.encode(enabled, forKey: .enabled)
        try values.encodeIfPresent(selectedSourceIDs, forKey: .selectedSourceIDs)
    }

    mutating func setShortcut(_ shortcut: Shortcut, replacing previous: Shortcut? = nil) -> ShortcutError? {
        guard shortcut.isValid else { return .invalid }
        if let previous {
            guard let index = shortcuts.firstIndex(of: previous) else { return .missing }
            guard !shortcuts.enumerated().contains(where: { $0.offset != index && $0.element == shortcut }) else {
                return .duplicate
            }
            shortcuts[index] = shortcut
        } else {
            guard !shortcuts.contains(shortcut) else { return .duplicate }
            shortcuts.append(shortcut)
        }
        return nil
    }

    @discardableResult
    mutating func removeShortcut(_ shortcut: Shortcut) -> Bool {
        guard shortcuts.count > 1, let index = shortcuts.firstIndex(of: shortcut) else { return false }
        shortcuts.remove(at: index)
        return true
    }

    mutating func restoreDefaultShortcut() { shortcuts = [.default] }
}
