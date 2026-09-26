import Foundation

public struct Modifiers: OptionSet, Codable, Hashable, Sendable {
    public let rawValue: UInt8
    public init(rawValue: UInt8) { self.rawValue = rawValue }

    public static let control = Self(rawValue: 1 << 0)
    public static let shift = Self(rawValue: 1 << 1)
    public static let option = Self(rawValue: 1 << 2)
    public static let command = Self(rawValue: 1 << 3)
    // Fn is tracked to reject extra modifiers, but cannot be assigned.
    public static let function = Self(rawValue: 1 << 4)
    public static let assignable: Self = [.control, .shift, .option, .command]

    public var symbols: String {
        [(Self.control, "⌃"), (.option, "⌥"), (.shift, "⇧"), (.command, "⌘")]
            .compactMap { contains($0.0) ? $0.1 : nil }.joined(separator: " ")
    }
}

public struct Shortcut: Codable, Equatable, Sendable {
    public var modifiers: Modifiers
    public var keyCode: UInt16?

    public init(modifiers: Modifiers, keyCode: UInt16? = nil) {
        self.modifiers = modifiers
        self.keyCode = keyCode
    }

    public static let `default` = Self(modifiers: [.control, .shift])

    public var isValid: Bool {
        guard modifiers.subtracting(.assignable).isEmpty else { return false }
        if let keyCode {
            return !modifiers.isEmpty && KeyNames.names[keyCode] != nil
        }
        return modifiers.rawValue.nonzeroBitCount >= 2
    }

    public var displayName: String {
        ([modifiers.symbols] + (keyCode.map { [KeyNames.name(for: $0)] } ?? []))
            .joined(separator: " ")
    }
}

/// Physical key positions, independent of the current input language.
public enum KeyNames {
    public static func name(for code: UInt16) -> String { names[code] ?? "Key \(code)" }

    public static let names: [UInt16: String] = [
        0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X",
        8: "C", 9: "V", 10: "§", 11: "B", 12: "Q", 13: "W", 14: "E", 15: "R",
        16: "Y", 17: "T", 18: "1", 19: "2", 20: "3", 21: "4", 22: "6", 23: "5",
        24: "=", 25: "9", 26: "7", 27: "−", 28: "8", 29: "0", 30: "]", 31: "O",
        32: "U", 33: "[", 34: "I", 35: "P", 36: "Return", 37: "L", 38: "J",
        39: "'", 40: "K", 41: ";", 42: "\\", 43: ",", 44: "/", 45: "N", 46: "M",
        47: ".", 48: "Tab", 49: "Space", 50: "`", 51: "⌫", 53: "Esc",
        65: "Num .", 67: "Num *", 69: "Num +", 71: "Clear", 75: "Num /",
        76: "Num Enter", 78: "Num −", 81: "Num =", 82: "Num 0", 83: "Num 1",
        84: "Num 2", 85: "Num 3", 86: "Num 4", 87: "Num 5", 88: "Num 6",
        89: "Num 7", 91: "Num 8", 92: "Num 9", 96: "F5", 97: "F6", 98: "F7",
        99: "F3", 100: "F8", 101: "F9", 103: "F11", 105: "F13", 106: "F16",
        107: "F14", 109: "F10", 111: "F12", 113: "F15", 114: "Help", 115: "Home",
        116: "Page Up", 117: "⌦", 118: "F4", 119: "End", 120: "F2",
        121: "Page Down", 122: "F1", 123: "←", 124: "→", 125: "↓", 126: "↑",
    ]
}
