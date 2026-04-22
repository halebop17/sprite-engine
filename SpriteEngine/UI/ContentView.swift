import SwiftUI
import MetalKit
import AppKit
import UniformTypeIdentifiers

// MARK: - Navigation root

struct ContentView: View {

    @EnvironmentObject private var appState: AppState

    var body: some View {
        Group {
            switch appState.screen {
            case .library:
                LibraryView()
            case .detail(let game):
                DetailView(game: game)
            case .`import`:
                ImportView()
            case .settings:
                SettingsPlaceholderView()
            case .emulator(let game):
                EmulatorHostView(game: game)
            }
        }
        .frame(minWidth: 640, minHeight: 480)
        .environment(\.appTheme, appState.currentTheme)
    }
}

// MARK: - Placeholder screens (replaced in Phase 17)

private struct SettingsPlaceholderView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 16) {
                Text("Settings").font(.title).bold().foregroundColor(.white)
                Text("(Phase 17)").foregroundColor(.secondary)
                Button("Back") { appState.navigateBack() }.buttonStyle(.bordered)
            }
        }
    }
}

// MARK: - Emulator host (inline until Phase 16 builds EmulatorWindowView)

@MainActor
private final class PlaybackViewModel: ObservableObject {

    let emulatorView = EmulatorView(frame: .zero, device: MTLCreateSystemDefaultDevice())
    let inputManager = InputManager()

    @Published var isRunning    = false
    @Published var errorMessage: String?

    private var session: EmulatorSession?

    init() {
        inputManager.startControllerDiscovery()
        emulatorView.inputManager = inputManager
    }

    func launch(game: Game, biosDirectory: URL?) {
        guard let biosDir = biosDirectory else {
            errorMessage = "BIOS folder not set. Go to Settings."
            return
        }
        stopSession()
        let router = CoreRouter()
        let core: any EmulatorCore
        do {
            core = try router.core(for: game.romURL)
            try core.loadROM(at: game.romURL, biosDirectory: biosDir)
        } catch {
            errorMessage = error.localizedDescription
            return
        }
        let s = EmulatorSession(core: core)
        s.onFrameReady = { [weak self, weak s] in
            guard let self, let s else { return }
            s.withFrontBuffer { pixels, w, h in
                self.emulatorView.update(pixels: pixels, width: w, height: h)
            }
        }
        inputManager.onInputChanged    = { [weak s] p, b in s?.setInput(player: p, buttons: b) }
        inputManager.onSysInputChanged = { [weak s] b in s?.setSysInput(b) }
        session = s
        isRunning = true
        s.start()
    }

    func stopSession() {
        session?.stop()
        session = nil
        inputManager.onInputChanged    = nil
        inputManager.onSysInputChanged = nil
        isRunning = false
    }
}

private struct EmulatorHostView: View {

    let game: Game
    @EnvironmentObject private var appState: AppState
    @StateObject private var vm = PlaybackViewModel()

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            EmulatorViewRepresentable(emulatorView: vm.emulatorView)
            if !vm.isRunning {
                VStack(spacing: 16) {
                    Text(game.title).font(.title).bold().foregroundColor(.white)
                    if let err = vm.errorMessage {
                        Text(err).foregroundColor(.red).multilineTextAlignment(.center)
                    }
                    Button("Back to Library") { appState.navigateBack() }
                        .buttonStyle(.bordered)
                }
                .padding(24)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
            }
        }
        .onChange(of: vm.isRunning) { running in
            if running { vm.emulatorView.window?.makeFirstResponder(vm.emulatorView) }
        }
        .alert("Error",
               isPresented: Binding(
                   get: { vm.errorMessage != nil },
                   set: { if !$0 { vm.errorMessage = nil } }
               ),
               actions: { Button("OK") { vm.errorMessage = nil } },
               message: { Text(vm.errorMessage ?? "") })
        .onAppear { vm.launch(game: game, biosDirectory: appState.biosDirectoryURL) }
        .onDisappear { vm.stopSession() }
    }
}
