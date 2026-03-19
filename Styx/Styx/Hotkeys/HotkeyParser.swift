import Carbon
import Foundation

struct ParsedKeyCombo {
    struct Modifiers: OptionSet {
        let rawValue: UInt32
        static let command = Modifiers(rawValue: 1 << 0)
        static let control = Modifiers(rawValue: 1 << 1)
        static let option  = Modifiers(rawValue: 1 << 2)
        static let shift   = Modifiers(rawValue: 1 << 3)
    }

    let keyString: String
    let modifiers: Modifiers
}

enum HotkeyParser {
    static func parse(_ str: String) -> ParsedKeyCombo? {
        let parts = str.split(separator: "+").map { $0.trimmingCharacters(in: .whitespaces) }
        guard let keyPart = parts.last, !keyPart.isEmpty else { return nil }
        guard parts.count >= 2 || !isModifier(keyPart) else { return nil }

        var modifiers: ParsedKeyCombo.Modifiers = []
        for part in parts.dropLast() {
            switch part.lowercased() {
            case "cmd", "command": modifiers.insert(.command)
            case "ctrl", "control": modifiers.insert(.control)
            case "alt", "option": modifiers.insert(.option)
            case "shift": modifiers.insert(.shift)
            default: break
            }
        }

        return ParsedKeyCombo(keyString: keyPart.lowercased(), modifiers: modifiers)
    }

    private static func isModifier(_ str: String) -> Bool {
        ["cmd", "command", "ctrl", "control", "alt", "option", "shift"]
            .contains(str.lowercased())
    }

    static func carbonKeyCode(for keyString: String) -> UInt32? {
        let map: [String: Int] = [
            "a": kVK_ANSI_A, "b": kVK_ANSI_B, "c": kVK_ANSI_C, "d": kVK_ANSI_D,
            "e": kVK_ANSI_E, "f": kVK_ANSI_F, "g": kVK_ANSI_G, "h": kVK_ANSI_H,
            "i": kVK_ANSI_I, "j": kVK_ANSI_J, "k": kVK_ANSI_K, "l": kVK_ANSI_L,
            "m": kVK_ANSI_M, "n": kVK_ANSI_N, "o": kVK_ANSI_O, "p": kVK_ANSI_P,
            "q": kVK_ANSI_Q, "r": kVK_ANSI_R, "s": kVK_ANSI_S, "t": kVK_ANSI_T,
            "u": kVK_ANSI_U, "v": kVK_ANSI_V, "w": kVK_ANSI_W, "x": kVK_ANSI_X,
            "y": kVK_ANSI_Y, "z": kVK_ANSI_Z,
            "1": kVK_ANSI_1, "2": kVK_ANSI_2, "3": kVK_ANSI_3, "4": kVK_ANSI_4,
            "5": kVK_ANSI_5, "6": kVK_ANSI_6, "7": kVK_ANSI_7, "8": kVK_ANSI_8,
            "9": kVK_ANSI_9, "0": kVK_ANSI_0,
            "tab": kVK_Tab, "space": kVK_Space, "return": kVK_Return,
            "escape": kVK_Escape, "delete": kVK_Delete,
            "f1": kVK_F1, "f2": kVK_F2, "f3": kVK_F3,
            "f4": kVK_F4, "f5": kVK_F5, "f6": kVK_F6,
            "f7": kVK_F7, "f8": kVK_F8, "f9": kVK_F9,
        ]
        return map[keyString].map { UInt32($0) }
    }

    static func carbonModifiers(for modifiers: ParsedKeyCombo.Modifiers) -> UInt32 {
        var result: UInt32 = 0
        if modifiers.contains(.command) { result |= UInt32(cmdKey) }
        if modifiers.contains(.control) { result |= UInt32(controlKey) }
        if modifiers.contains(.option)  { result |= UInt32(optionKey) }
        if modifiers.contains(.shift)   { result |= UInt32(shiftKey) }
        return result
    }
}
