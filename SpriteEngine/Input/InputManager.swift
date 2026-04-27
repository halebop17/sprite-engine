import GameController

final class InputManager {

    // MARK: - Button bitmask (matches GEO_BTN_* bit positions in geolith_bridge.h)
    struct Buttons: OptionSet {
        let rawValue: UInt32
        static let up     = Buttons(rawValue: 1 << 0)
        static let down   = Buttons(rawValue: 1 << 1)
        static let left   = Buttons(rawValue: 1 << 2)
        static let right  = Buttons(rawValue: 1 << 3)
        static let select = Buttons(rawValue: 1 << 4)
        static let start  = Buttons(rawValue: 1 << 5)
        static let a      = Buttons(rawValue: 1 << 6)
        static let b      = Buttons(rawValue: 1 << 7)
        static let c      = Buttons(rawValue: 1 << 8)
        static let d      = Buttons(rawValue: 1 << 9)
    }

    // Fired on any thread — caller forwards to core.setInput(player:buttons:).
    var onInputChanged:    ((Int, UInt32) -> Void)?
    // Fired for system inputs (coin, service) — caller forwards to core.setSysInput.
    var onSysInputChanged: ((UInt32) -> Void)?

    // MARK: - Active profile

    /// Current profile applied for keyboard + gamepad lookups. Defaults to
    /// the built-in Neo Geo profile until `setSystem(_:)` is called.
    private var profile: InputProfile = InputProfile.builtIn(for: .neoGeoMVS)
    private(set) var activeSystem: EmulatorSystem = .neoGeoMVS

    /// Switch to the profile for a different system. Called by
    /// `EmulatorWindowView` when a game starts.
    @MainActor
    func setSystem(_ system: EmulatorSystem) {
        activeSystem = system
        profile = ControllerSettings.shared.profile(for: system)
    }

    // MARK: - Keyboard state

    private var keyboardState: [UInt16: Bool] = [:]

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
        // Player 1 game buttons + start/select via the active profile's keyboard map
        for (logical, code) in profile.keyboard where code == keyCode {
            switch logical {
            case .coin:
                let current = currentSysButtons()
                let bit: UInt32 = 1 << UInt32(GEO_SYS_COIN1)
                let updated = pressed ? (current | bit) : (current & ~bit)
                onSysInputChanged?(updated)
            default:
                guard let bit = bitmaskBit(for: logical) else { continue }
                let current = currentButtons(for: 0)
                let updated: Buttons = pressed
                    ? current.union(bit)
                    : current.subtracting(bit)
                onInputChanged?(0, updated.rawValue)
            }
        }
    }

    private func currentButtons(for player: Int) -> Buttons {
        // Player 0 always reflects the keyboard. Player 1 is gamepad-only
        // until/unless we add a second keymap; the gamepad path computes its
        // own state from the live pad on every value-change callback.
        guard player == 0 else { return [] }
        var result = Buttons()
        for (logical, code) in profile.keyboard {
            if keyboardState[code] == true, let bit = bitmaskBit(for: logical) {
                result.insert(bit)
            }
        }
        return result
    }

    private func currentSysButtons() -> UInt32 {
        var result: UInt32 = 0
        if let coinKey = profile.keyboard[.coin], keyboardState[coinKey] == true {
            result |= (1 << UInt32(GEO_SYS_COIN1))
        }
        return result
    }

    private func bitmaskBit(for button: CoreButton) -> Buttons? {
        switch button {
        case .up:     return .up
        case .down:   return .down
        case .left:   return .left
        case .right:  return .right
        case .a:      return .a
        case .b:      return .b
        case .c:      return .c
        case .d:      return .d
        case .start:  return .start
        case .select: return .select
        case .coin:   return nil   // routed through SysInputs, not the OptionSet
        }
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

        for controller in GCController.controllers() {
            wireController(controller)
        }
    }

    @objc private func controllerConnected(_ note: Notification) {
        guard let controller = note.object as? GCController else { return }
        wireController(controller)
    }

    @objc private func controllerDisconnected(_ note: Notification) {
        // valueChangedHandler clears itself when the controller disconnects.
    }

    private func wireController(_ controller: GCController) {
        // Map the first two connected controllers to players 0 and 1.
        let all = GCController.controllers()
        guard let idx = all.firstIndex(of: controller), idx < 2 else { return }
        let player = idx

        controller.extendedGamepad?.valueChangedHandler = { [weak self] pad, _ in
            guard let self else { return }
            var b = Buttons()
            var sys: UInt32 = 0

            for (logical, mapped) in self.profile.gamepad {
                if Self.isPressed(mapped, on: pad) {
                    if logical == .coin {
                        sys |= (1 << UInt32(GEO_SYS_COIN1))
                    } else if let bit = self.bitmaskBit(for: logical) {
                        b.insert(bit)
                    }
                }
            }
            // Always-on left-stick fallback for direction (independent of profile)
            let lx = pad.leftThumbstick.xAxis.value
            let ly = pad.leftThumbstick.yAxis.value
            if ly >  0.5 { b.insert(.up)    }
            if ly < -0.5 { b.insert(.down)  }
            if lx < -0.5 { b.insert(.left)  }
            if lx >  0.5 { b.insert(.right) }

            self.onInputChanged?(player, b.rawValue)
            // Player 0 owns sysinput (coin) for the gamepad path so a P1
            // pad can drop credits.
            if player == 0 { self.onSysInputChanged?(sys) }
        }
    }

    /// Test whether a given physical gamepad button is currently pressed.
    static func isPressed(_ button: GamepadButton, on pad: GCExtendedGamepad) -> Bool {
        switch button {
        case .dpadUp:           return pad.dpad.up.isPressed
        case .dpadDown:         return pad.dpad.down.isPressed
        case .dpadLeft:         return pad.dpad.left.isPressed
        case .dpadRight:        return pad.dpad.right.isPressed
        case .faceA:            return pad.buttonA.isPressed
        case .faceB:            return pad.buttonB.isPressed
        case .faceX:            return pad.buttonX.isPressed
        case .faceY:            return pad.buttonY.isPressed
        case .leftBumper:       return pad.leftShoulder.isPressed
        case .rightBumper:      return pad.rightShoulder.isPressed
        case .leftTrigger:      return pad.leftTrigger.isPressed
        case .rightTrigger:     return pad.rightTrigger.isPressed
        case .menu:             return pad.buttonMenu.isPressed
        case .options:          return pad.buttonOptions?.isPressed == true
        case .leftStickClick:   return pad.leftThumbstickButton?.isPressed == true
        case .rightStickClick:  return pad.rightThumbstickButton?.isPressed == true
        }
    }
}
