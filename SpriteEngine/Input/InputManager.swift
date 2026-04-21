import GameController

final class InputManager {

    // MARK: - Button bitmask (matches GEO_BTN_* bit positions in geolith_bridge.h)
    struct Buttons: OptionSet {
        let rawValue: UInt32
        static let up     = Buttons(rawValue: 1 << 0)  // GEO_BTN_UP
        static let down   = Buttons(rawValue: 1 << 1)  // GEO_BTN_DOWN
        static let left   = Buttons(rawValue: 1 << 2)  // GEO_BTN_LEFT
        static let right  = Buttons(rawValue: 1 << 3)  // GEO_BTN_RIGHT
        static let select = Buttons(rawValue: 1 << 4)  // GEO_BTN_SELECT
        static let start  = Buttons(rawValue: 1 << 5)  // GEO_BTN_START
        static let a      = Buttons(rawValue: 1 << 6)  // GEO_BTN_A
        static let b      = Buttons(rawValue: 1 << 7)  // GEO_BTN_B
        static let c      = Buttons(rawValue: 1 << 8)  // GEO_BTN_C
        static let d      = Buttons(rawValue: 1 << 9)  // GEO_BTN_D
    }

    // Fired on any thread — caller forwards to core.setInput(player:buttons:).
    var onInputChanged:    ((Int, UInt32) -> Void)?
    // Fired for system inputs (coin, service) — caller forwards to core.setSysInput.
    var onSysInputChanged: ((UInt32) -> Void)?

    // MARK: - Keyboard state

    private var keyboardState: [UInt16: Bool] = [:]

    // P1: WASD / arrows for direction; U/I/J/K for A/B/C/D; Return=START; Space=SELECT
    private let playerKeymap: [UInt16: (player: Int, button: Buttons)] = [
        // Player 1 — WASD
        0x0D: (0, .up),    // W
        0x01: (0, .down),  // S
        0x00: (0, .left),  // A
        0x02: (0, .right), // D
        // Player 1 — arrow keys (alternative)
        0x7E: (0, .up),
        0x7D: (0, .down),
        0x7B: (0, .left),
        0x7C: (0, .right),
        // Player 1 — buttons
        0x20: (0, .a),     // U
        0x22: (0, .b),     // I
        0x26: (0, .c),     // J
        0x28: (0, .d),     // K
        0x24: (0, .start), // Return
        0x31: (0, .select),// Space
    ]

    // System inputs — C = Coin 1 insert (needed for MVS boot)
    private let sysKeymap: [UInt16: UInt32] = [
        0x08: (1 << Int(GEO_SYS_COIN1)),  // C key = Coin 1
    ]

    // MARK: - Keyboard event handlers (called from EmulatorView)

    func keyDown(keyCode: UInt16) {
        guard keyboardState[keyCode] != true else { return } // ignore key repeat
        keyboardState[keyCode] = true
        handleKey(keyCode: keyCode, pressed: true)
    }

    func keyUp(keyCode: UInt16) {
        keyboardState[keyCode] = false
        handleKey(keyCode: keyCode, pressed: false)
    }

    private func handleKey(keyCode: UInt16, pressed: Bool) {
        if let (player, button) = playerKeymap[keyCode] {
            let buttons = currentButtons(for: player)
            let updated = pressed
                ? buttons.union(button)
                : buttons.subtracting(button)
            onInputChanged?(player, updated.rawValue)
        }

        if let sysbit = sysKeymap[keyCode] {
            let current = currentSysButtons()
            let updated = pressed ? (current | sysbit) : (current & ~sysbit)
            onSysInputChanged?(updated)
        }
    }

    // Rebuild current button state for a player from the live keyboard map.
    private func currentButtons(for player: Int) -> Buttons {
        var result = Buttons()
        for (code, mapping) in playerKeymap where mapping.player == player {
            if keyboardState[code] == true {
                result.insert(mapping.button)
            }
        }
        return result
    }

    private func currentSysButtons() -> UInt32 {
        var result: UInt32 = 0
        for (code, bits) in sysKeymap {
            if keyboardState[code] == true { result |= bits }
        }
        return result
    }

    // MARK: - GCController (MFi / Xbox / DualSense)

    func startControllerDiscovery() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(controllerConnected(_:)),
            name: .GCControllerDidConnect,
            object: nil)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(controllerDisconnected(_:)),
            name: .GCControllerDidDisconnect,
            object: nil)
        GCController.startWirelessControllerDiscovery {}

        // Wire any already-connected controllers.
        for controller in GCController.controllers() {
            wireController(controller)
        }
    }

    @objc private func controllerConnected(_ note: Notification) {
        guard let controller = note.object as? GCController else { return }
        wireController(controller)
    }

    @objc private func controllerDisconnected(_ note: Notification) {
        // valueChangedHandler is cleared when the controller disconnects naturally.
    }

    private func wireController(_ controller: GCController) {
        // Map the first two connected controllers to players 0 and 1.
        let all = GCController.controllers()
        guard let idx = all.firstIndex(of: controller), idx < 2 else { return }
        let player = idx

        controller.extendedGamepad?.valueChangedHandler = { [weak self] pad, _ in
            var b = Buttons()
            if pad.dpad.up.isPressed       { b.insert(.up)    }
            if pad.dpad.down.isPressed     { b.insert(.down)  }
            if pad.dpad.left.isPressed     { b.insert(.left)  }
            if pad.dpad.right.isPressed    { b.insert(.right) }
            if pad.buttonA.isPressed       { b.insert(.a)     }
            if pad.buttonB.isPressed       { b.insert(.b)     }
            if pad.buttonX.isPressed       { b.insert(.c)     }
            if pad.buttonY.isPressed       { b.insert(.d)     }
            if pad.buttonMenu.isPressed    { b.insert(.start) }
            if pad.buttonOptions?.isPressed == true { b.insert(.select) }
            // Left stick as d-pad fallback
            let lx = pad.leftThumbstick.xAxis.value
            let ly = pad.leftThumbstick.yAxis.value
            if ly >  0.5 { b.insert(.up)    }
            if ly < -0.5 { b.insert(.down)  }
            if lx < -0.5 { b.insert(.left)  }
            if lx >  0.5 { b.insert(.right) }

            self?.onInputChanged?(player, b.rawValue)
        }
    }
}
