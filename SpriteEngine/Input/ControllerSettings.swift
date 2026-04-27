import Foundation
import Combine

/// Persistent store for per-system controller overrides. Built-in defaults
/// always apply unless the user has explicitly customised a binding.
@MainActor
final class ControllerSettings: ObservableObject {

    static let shared = ControllerSettings()

    /// Bumped on every save so SwiftUI views observing the settings can
    /// re-read the effective profile for whichever system they're showing.
    @Published private(set) var revision = 0

    private init() {}

    // MARK: - Read

    /// Effective profile for `system` — built-in default with any user
    /// override merged on top.
    func profile(for system: EmulatorSystem) -> InputProfile {
        let base = InputProfile.builtIn(for: system)
        guard let override = override(for: system) else { return base }
        return override.merged(over: base)
    }

    /// Returns just the override (if any). Used by the settings UI to know
    /// whether the system has been customised vs. fully default.
    func override(for system: EmulatorSystem) -> InputProfile? {
        let key = Self.key(for: system)
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(InputProfile.self, from: data)
    }

    func hasOverride(for system: EmulatorSystem) -> Bool {
        UserDefaults.standard.data(forKey: Self.key(for: system)) != nil
    }

    // MARK: - Write

    /// Persist a single key binding for one system.
    func setKeyboardBinding(_ keyCode: UInt16?,
                            for button: CoreButton,
                            system: EmulatorSystem) {
        var override = self.override(for: system) ?? InputProfile.empty
        if let keyCode { override.keyboard[button] = keyCode }
        else           { override.keyboard.removeValue(forKey: button) }
        save(override, for: system)
    }

    /// Persist a single gamepad binding for one system.
    func setGamepadBinding(_ pad: GamepadButton?,
                           for button: CoreButton,
                           system: EmulatorSystem) {
        var override = self.override(for: system) ?? InputProfile.empty
        if let pad { override.gamepad[button] = pad }
        else       { override.gamepad.removeValue(forKey: button) }
        save(override, for: system)
    }

    /// Wipe the override for one system (revert to shipped defaults).
    func clearOverride(for system: EmulatorSystem) {
        UserDefaults.standard.removeObject(forKey: Self.key(for: system))
        revision &+= 1
    }

    // MARK: - Internals

    private func save(_ profile: InputProfile, for system: EmulatorSystem) {
        if profile.keyboard.isEmpty && profile.gamepad.isEmpty {
            UserDefaults.standard.removeObject(forKey: Self.key(for: system))
        } else if let data = try? JSONEncoder().encode(profile) {
            UserDefaults.standard.set(data, forKey: Self.key(for: system))
        }
        revision &+= 1
    }

    private static func key(for system: EmulatorSystem) -> String {
        "inputProfile.\(system.rawValue)"
    }
}
