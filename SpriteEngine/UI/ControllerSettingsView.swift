import SwiftUI
import GameController
import AppKit

struct ControllerSettingsView: View {

    @ObservedObject private var settings = ControllerSettings.shared
    @Environment(\.appTheme) private var t
    @State private var system: EmulatorSystem = .neoGeoMVS
    @State private var bindRequest: BindRequest?

    private var visibleButtons: [CoreButton] { CoreButton.visible(for: system) }
    private var profile: InputProfile { settings.profile(for: system) }
    private var hasOverride: Bool { settings.hasOverride(for: system) }

    var body: some View {
        VStack(spacing: 0) {
            topBar
            Divider().background(t.divider)
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    intro
                    systemPicker
                    bindings
                }
                .padding(26)
                .frame(maxWidth: 760, alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .background(t.surface)
        .sheet(item: $bindRequest) { req in
            BindCaptureSheet(request: req,
                             system: system,
                             onComplete: { bindRequest = nil })
                .environment(\.appTheme, t)
        }
    }

    // MARK: - Top bar

    private var topBar: some View {
        HStack {
            BackButton()
            Spacer()
            Text("Controllers")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(t.text)
            Spacer()
            Color.clear.frame(width: 60, height: 1)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(t.toolbar)
    }

    // MARK: - Intro

    private var intro: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Per-System Controller Mapping")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(t.text)
            Text("Defaults work for most games. Override individual buttons here to suit a particular system. Each system stores its own override; clearing one system has no effect on the others.")
                .font(.system(size: 12))
                .foregroundColor(t.textMuted)
                .lineSpacing(3)
        }
    }

    // MARK: - System picker

    private var systemPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("CONFIGURING FOR")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(t.textFaint)
                .kerning(0.8)
            Picker("", selection: $system) {
                ForEach(EmulatorSystem.allCases, id: \.self) { s in
                    Text(s.rawValue + (settings.hasOverride(for: s) ? "  •" : ""))
                        .tag(s)
                }
            }
            .pickerStyle(.menu)
            .frame(maxWidth: 320, alignment: .leading)
        }
    }

    // MARK: - Bindings

    private var bindings: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("BUTTONS")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(t.textFaint)
                    .kerning(0.8)
                Spacer()
                if hasOverride {
                    Button("Reset \(system.rawValue) to Defaults") {
                        settings.clearOverride(for: system)
                    }
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.red)
                    .buttonStyle(.plain)
                }
            }

            VStack(spacing: 0) {
                // Header row
                HStack(spacing: 0) {
                    Text("BUTTON")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(t.textFaint)
                        .kerning(0.6)
                        .frame(width: 130, alignment: .leading)
                    Text("KEYBOARD")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(t.textFaint)
                        .kerning(0.6)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text("GAMEPAD")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(t.textFaint)
                        .kerning(0.6)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background(t.systemTabsBg)

                Divider().background(t.divider)

                ForEach(visibleButtons) { button in
                    BindingRow(
                        button: button,
                        keyboard: profile.keyboard[button],
                        gamepad:  profile.gamepad[button],
                        onTapKeyboard: { bindRequest = BindRequest(button: button, kind: .keyboard) },
                        onTapGamepad:  { bindRequest = BindRequest(button: button, kind: .gamepad) }
                    )
                    if button != visibleButtons.last {
                        Divider().background(t.divider).padding(.leading, 14)
                    }
                }
            }
            .background(t.card)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(t.cardBorder, lineWidth: 1))
        }
    }
}

// MARK: - Binding row

private struct BindingRow: View {
    let button: CoreButton
    let keyboard: UInt16?
    let gamepad:  GamepadButton?
    let onTapKeyboard: () -> Void
    let onTapGamepad:  () -> Void
    @Environment(\.appTheme) private var t

    var body: some View {
        HStack(spacing: 0) {
            Text(button.label)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(t.text)
                .frame(width: 130, alignment: .leading)
            BindingChip(
                label: keyboard.map { KeyCodeLabels.label(for: $0) } ?? "—",
                isSet: keyboard != nil,
                action: onTapKeyboard
            )
            .frame(maxWidth: .infinity, alignment: .leading)
            BindingChip(
                label: gamepad?.label ?? "—",
                isSet: gamepad != nil,
                action: onTapGamepad
            )
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
    }
}

private struct BindingChip: View {
    let label: String
    let isSet: Bool
    let action: () -> Void
    @Environment(\.appTheme) private var t
    @State private var hovered = false

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(isSet ? t.text : t.textFaint)
                .padding(.horizontal, 9)
                .padding(.vertical, 4)
                .background(hovered ? t.cardHover : t.surface.opacity(0.5))
                .clipShape(RoundedRectangle(cornerRadius: 5))
                .overlay(RoundedRectangle(cornerRadius: 5)
                    .strokeBorder(hovered ? t.accent.opacity(0.6) : t.cardBorder, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .onHover { hovered = $0 }
        .help("Click to rebind")
    }
}

// MARK: - Bind capture sheet

struct BindRequest: Identifiable {
    enum Kind { case keyboard, gamepad }
    let button: CoreButton
    let kind: Kind
    var id: String { "\(button.rawValue)-\(kind == .keyboard ? "k" : "g")" }
}

private struct BindCaptureSheet: View {

    let request: BindRequest
    let system: EmulatorSystem
    let onComplete: () -> Void

    @ObservedObject private var settings = ControllerSettings.shared
    @Environment(\.appTheme) private var t
    @State private var keyMonitor: Any?
    @State private var captured: String?

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 8) {
                Image(systemName: request.kind == .keyboard ? "keyboard" : "gamecontroller")
                    .font(.system(size: 36))
                    .foregroundColor(t.accent)
                Text("Press a \(request.kind == .keyboard ? "key" : "button")")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(t.text)
                Text("Binding \(request.button.label) for \(system.rawValue)")
                    .font(.system(size: 12))
                    .foregroundColor(t.textMuted)
                if let c = captured {
                    Text("Bound: \(c)")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.green)
                        .padding(.top, 6)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 36)

            Divider().background(t.divider)

            HStack {
                Button("Clear Binding") {
                    if request.kind == .keyboard {
                        settings.setKeyboardBinding(nil, for: request.button, system: system)
                    } else {
                        settings.setGamepadBinding(nil, for: request.button, system: system)
                    }
                    onComplete()
                }
                .font(.system(size: 12))
                .foregroundColor(.red)
                .buttonStyle(.plain)
                Spacer()
                Button("Cancel", action: onComplete)
                    .keyboardShortcut(.cancelAction)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .frame(width: 380)
        .background(t.surface)
        .onAppear { begin() }
        .onDisappear { stop() }
    }

    // MARK: - Capture

    private func begin() {
        switch request.kind {
        case .keyboard:
            keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                if event.keyCode == 53 { // Esc cancels
                    DispatchQueue.main.async { onComplete() }
                    return nil
                }
                let code = event.keyCode
                settings.setKeyboardBinding(code, for: request.button, system: system)
                captured = KeyCodeLabels.label(for: code)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { onComplete() }
                return nil
            }
        case .gamepad:
            for controller in GCController.controllers() {
                attachCapture(to: controller)
            }
        }
    }

    private func stop() {
        if let m = keyMonitor { NSEvent.removeMonitor(m); keyMonitor = nil }
        for controller in GCController.controllers() {
            controller.extendedGamepad?.valueChangedHandler = nil
            // Restore the live handler by triggering a fresh wire on the
            // app's InputManager next frame. The shared instance gets
            // rewired automatically on next emulator launch; for now we
            // simply clear the temporary one so menu use isn't disturbed.
        }
    }

    private func attachCapture(to controller: GCController) {
        controller.extendedGamepad?.valueChangedHandler = { [self] _, element in
            guard captured == nil else { return }
            for candidate in GamepadButton.allCases {
                if let pad = controller.extendedGamepad,
                   InputManager.isPressed(candidate, on: pad) {
                    settings.setGamepadBinding(candidate, for: request.button, system: system)
                    captured = candidate.label
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { onComplete() }
                    return
                }
            }
            _ = element
        }
    }
}
