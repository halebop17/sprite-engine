import Foundation

// MARK: - Logical buttons sent to the cores

enum CoreButton: String, Codable, CaseIterable, Identifiable {
    case up, down, left, right
    case a, b, c, d
    case start, select
    case coin

    var id: String { rawValue }

    /// Display label shown in the Controllers settings UI.
    var label: String {
        switch self {
        case .up:     return "Up"
        case .down:   return "Down"
        case .left:   return "Left"
        case .right:  return "Right"
        case .a:      return "Button A"
        case .b:      return "Button B"
        case .c:      return "Button C"
        case .d:      return "Button D"
        case .start:  return "Start"
        case .select: return "Select"
        case .coin:   return "Insert Coin"
        }
    }

    /// True for the four-direction d-pad inputs.
    var isDirection: Bool {
        self == .up || self == .down || self == .left || self == .right
    }

    /// Buttons that are visible/configurable for a given system. Buttons
    /// without a real meaning on the system are hidden in the UI.
    static func visible(for system: EmulatorSystem) -> [CoreButton] {
        var keys: [CoreButton] = [.up, .down, .left, .right]
        let buttonCount: Int = {
            switch system {
            case .neoGeoAES, .neoGeoMVS, .neoGeoCD: return 4
            case .cps1, .cps2:                       return 4   // bitmask currently 4-wide
            case .konamiGX, .konami68k:              return 4
            case .segaSys16, .segaSys18:             return 3
            case .toaplan1, .toaplan2:               return 2
            case .irem:                              return 3
            case .taito:                             return 3
            }
        }()
        let allButtons: [CoreButton] = [.a, .b, .c, .d]
        keys.append(contentsOf: allButtons.prefix(buttonCount))
        keys.append(contentsOf: [.start, .select, .coin])
        return keys
    }
}

// MARK: - Physical gamepad buttons

enum GamepadButton: String, Codable, CaseIterable, Identifiable {
    case dpadUp, dpadDown, dpadLeft, dpadRight
    case faceA, faceB, faceX, faceY
    case leftBumper, rightBumper
    case leftTrigger, rightTrigger
    case menu, options
    case leftStickClick, rightStickClick

    var id: String { rawValue }

    var label: String {
        switch self {
        case .dpadUp:           return "D-Pad ↑"
        case .dpadDown:         return "D-Pad ↓"
        case .dpadLeft:         return "D-Pad ←"
        case .dpadRight:        return "D-Pad →"
        case .faceA:            return "A (bottom)"
        case .faceB:            return "B (right)"
        case .faceX:            return "X (left)"
        case .faceY:            return "Y (top)"
        case .leftBumper:       return "LB"
        case .rightBumper:      return "RB"
        case .leftTrigger:      return "LT"
        case .rightTrigger:     return "RT"
        case .menu:             return "Menu"
        case .options:          return "Options / View"
        case .leftStickClick:   return "L-Stick Click"
        case .rightStickClick:  return "R-Stick Click"
        }
    }
}

// MARK: - Profile

struct InputProfile: Codable, Equatable {
    /// Logical button → macOS keyCode (UInt16). Missing entries mean
    /// "unbound on the keyboard."
    var keyboard: [CoreButton: UInt16]
    /// Logical button → physical gamepad button. Missing entries mean
    /// "unbound on the gamepad."
    var gamepad:  [CoreButton: GamepadButton]

    static let empty = InputProfile(keyboard: [:], gamepad: [:])

    /// Built-in default for the given system. Today every system shares the
    /// same defaults — Phase 30 ships with no behaviour change. Per-system
    /// tweaks will be layered in later as we get user feedback (e.g. Sega
    /// might benefit from a row-style face-button mapping eventually).
    static func builtIn(for system: EmulatorSystem) -> InputProfile {
        InputProfile(
            keyboard: defaultKeyboard,
            gamepad:  defaultGamepad
        )
    }

    /// Apply `override` on top of `base`. Only buttons explicitly bound in
    /// `override` win. Lets us ship better defaults later without trampling
    /// user customisations.
    func merged(over base: InputProfile) -> InputProfile {
        var k = base.keyboard
        for (key, value) in keyboard { k[key] = value }
        var g = base.gamepad
        for (key, value) in gamepad { g[key] = value }
        return InputProfile(keyboard: k, gamepad: g)
    }

    // MARK: - Bundled defaults (match pre-Phase-30 hardcoded behaviour)

    /// macOS key codes — see `NSEvent.keyCode` reference.
    private static let defaultKeyboard: [CoreButton: UInt16] = [
        .up:     0x0D,   // W
        .down:   0x01,   // S
        .left:   0x00,   // A
        .right:  0x02,   // D
        .a:      0x20,   // U
        .b:      0x22,   // I
        .c:      0x26,   // J
        .d:      0x28,   // K
        .start:  0x24,   // Return
        .select: 0x31,   // Space
        .coin:   0x08,   // C
    ]

    private static let defaultGamepad: [CoreButton: GamepadButton] = [
        .up:     .dpadUp,
        .down:   .dpadDown,
        .left:   .dpadLeft,
        .right:  .dpadRight,
        .a:      .faceA,
        .b:      .faceB,
        .c:      .faceX,
        .d:      .faceY,
        .start:  .menu,
        .select: .options,
        .coin:   .leftBumper,
    ]
}

// MARK: - Keyboard key code → human label

enum KeyCodeLabels {
    /// US-layout label for a key code. Falls back to "Key 0xNN" for codes we
    /// don't have a friendly name for.
    static func label(for keyCode: UInt16) -> String {
        switch keyCode {
        case 0x00: return "A"
        case 0x01: return "S"
        case 0x02: return "D"
        case 0x03: return "F"
        case 0x04: return "H"
        case 0x05: return "G"
        case 0x06: return "Z"
        case 0x07: return "X"
        case 0x08: return "C"
        case 0x09: return "V"
        case 0x0B: return "B"
        case 0x0C: return "Q"
        case 0x0D: return "W"
        case 0x0E: return "E"
        case 0x0F: return "R"
        case 0x10: return "Y"
        case 0x11: return "T"
        case 0x12: return "1"
        case 0x13: return "2"
        case 0x14: return "3"
        case 0x15: return "4"
        case 0x16: return "6"
        case 0x17: return "5"
        case 0x19: return "9"
        case 0x1A: return "7"
        case 0x1C: return "8"
        case 0x1D: return "0"
        case 0x1F: return "O"
        case 0x20: return "U"
        case 0x22: return "I"
        case 0x23: return "P"
        case 0x25: return "L"
        case 0x26: return "J"
        case 0x28: return "K"
        case 0x2D: return "N"
        case 0x2E: return "M"
        case 0x24: return "Return"
        case 0x30: return "Tab"
        case 0x31: return "Space"
        case 0x33: return "Delete"
        case 0x35: return "Esc"
        case 0x7B: return "←"
        case 0x7C: return "→"
        case 0x7D: return "↓"
        case 0x7E: return "↑"
        default:   return String(format: "Key 0x%02X", keyCode)
        }
    }
}
