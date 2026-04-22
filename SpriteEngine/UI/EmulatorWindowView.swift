import SwiftUI
import MetalKit

// MARK: - ViewModel

@MainActor
final class EmulatorViewModel: ObservableObject {

    let emulatorView = EmulatorView(frame: .zero, device: MTLCreateSystemDefaultDevice())
    let inputManager = InputManager()

    @Published var isRunning    = false
    @Published var errorMessage: String?
    @Published var isPaused:    Bool = false
    @Published var measuredFPS: Double = 0
    @Published var statusMessage: String?

    private var session: EmulatorSession?
    private var statusTask: DispatchWorkItem?

    init() {
        inputManager.startControllerDiscovery()
        emulatorView.inputManager = inputManager
    }

    func launch(game: Game, biosDirectory: URL?, appState: AppState) {
        guard let biosDir = biosDirectory else {
            errorMessage = "BIOS folder not set — open Settings to configure it."
            return
        }
        stop()
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

        s.volume = appState.audioVolume
        applyVideoSettings(appState: appState)

        session = s
        isRunning = true

        Task {
            for await paused in s.$isPaused.values { self.isPaused = paused }
        }
        Task {
            for await fps in s.$measuredFPS.values { self.measuredFPS = fps }
        }

        s.start()
    }

    func stop() {
        session?.stop()
        session = nil
        inputManager.onInputChanged    = nil
        inputManager.onSysInputChanged = nil
        isRunning = false
        isPaused  = false
    }

    func togglePause() { session?.togglePause() }

    func applyVideoSettings(appState: AppState) {
        emulatorView.renderer?.scaleMode   = appState.videoScaleMode
        emulatorView.renderer?.filterMode  = appState.videoCRTFilter ? .crt : .sharp
    }

    func applyVolume(_ v: Float) { session?.volume = v }

    // MARK: - Save state

    func saveState(game: Game, library: ROMLibrary) {
        guard let session else { return }

        // Capture thumbnail pixels on main thread while holding the buffer lock.
        var pixels: [UInt32] = []
        var thumbW = 0, thumbH = 0
        session.withFrontBuffer { ptr, w, h in
            pixels = Array(UnsafeBufferPointer(start: ptr, count: w * h))
            thumbW = w; thumbH = h
        }

        do {
            let state = try SaveStateManager.save(
                game: game, session: session,
                thumbnailPixels: pixels, thumbnailWidth: thumbW, thumbnailHeight: thumbH)
            library.addSaveState(state, to: game)
            showStatus("State saved")
        } catch {
            errorMessage = "Save failed: \(error.localizedDescription)"
        }
    }

    func loadLatestState(game: Game) {
        guard let session else { return }
        let states = game.saveStates.sorted { $0.createdAt > $1.createdAt }
        guard let latest = states.first else {
            showStatus("No save states")
            return
        }
        let wasPaused = isPaused
        session.pause()
        do {
            try SaveStateManager.load(latest, into: session)
            showStatus("State loaded")
        } catch {
            errorMessage = "Load failed: \(error.localizedDescription)"
        }
        if !wasPaused { session.resume() }
    }

    // MARK: - Status toast

    private func showStatus(_ message: String) {
        statusTask?.cancel()
        statusMessage = message
        let task = DispatchWorkItem { [weak self] in self?.statusMessage = nil }
        statusTask = task
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8, execute: task)
    }
}

// MARK: - EmulatorWindowView

struct EmulatorWindowView: View {

    let game: Game

    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var library: ROMLibrary
    @StateObject private var vm = EmulatorViewModel()

    @State private var hudVisible = true
    @State private var hideTask: DispatchWorkItem?

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            EmulatorViewRepresentable(emulatorView: vm.emulatorView)

            if appState.showFPSOverlay && vm.isRunning {
                fpsOverlay
            }

            hudOverlay
                .opacity(hudVisible ? 1 : 0)
                .animation(.easeInOut(duration: 0.22), value: hudVisible)

            if let msg = vm.statusMessage {
                statusToast(msg)
            }
        }
        .onContinuousHover { phase in
            if case .active = phase { showHUD() }
        }
        .onAppear {
            vm.launch(game: game, biosDirectory: appState.biosDirectoryURL, appState: appState)
            showHUD()
        }
        .onDisappear { vm.stop() }
        .onChange(of: vm.isRunning) { _, running in
            if running { vm.emulatorView.window?.makeFirstResponder(vm.emulatorView) }
        }
        .onChange(of: appState.videoScaleMode) { _, _ in vm.applyVideoSettings(appState: appState) }
        .onChange(of: appState.videoCRTFilter) { _, _ in vm.applyVideoSettings(appState: appState) }
        .onChange(of: appState.audioVolume)    { _, v  in vm.applyVolume(v) }
        .alert("Error",
               isPresented: Binding(
                   get: { vm.errorMessage != nil },
                   set: { if !$0 { vm.errorMessage = nil } }),
               actions: { Button("OK") { vm.errorMessage = nil } },
               message: { Text(vm.errorMessage ?? "") })
    }

    // MARK: - FPS overlay

    private var fpsOverlay: some View {
        VStack {
            HStack {
                Spacer()
                Text(String(format: "%.0f FPS", vm.measuredFPS))
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundColor(.white.opacity(0.7))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.black.opacity(0.55), in: RoundedRectangle(cornerRadius: 5))
                    .padding(.top, 10)
                    .padding(.trailing, 12)
            }
            Spacer()
        }
    }

    // MARK: - Status toast

    private func statusToast(_ message: String) -> some View {
        VStack {
            Spacer()
            Text(message)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(.black.opacity(0.72), in: RoundedRectangle(cornerRadius: 10))
                .shadow(color: .black.opacity(0.3), radius: 12, y: 4)
                .padding(.bottom, 90)
                .transition(.opacity.combined(with: .scale(scale: 0.92)))
                .animation(.easeInOut(duration: 0.18), value: vm.statusMessage)
        }
    }

    // MARK: - HUD overlay

    private var hudOverlay: some View {
        VStack(spacing: 0) {
            LinearGradient(colors: [.black.opacity(0.7), .clear], startPoint: .top, endPoint: .bottom)
                .frame(height: 72)
                .overlay(alignment: .topLeading) {
                    topBar.padding(.horizontal, 16).padding(.top, 14)
                }

            Spacer()

            LinearGradient(colors: [.clear, .black.opacity(0.65)], startPoint: .top, endPoint: .bottom)
                .frame(height: 80)
                .overlay(alignment: .bottom) {
                    bottomBar.padding(.horizontal, 24).padding(.bottom, 14)
                }
        }
        .ignoresSafeArea()
    }

    private var topBar: some View {
        HStack(spacing: 10) {
            Button {
                vm.stop()
                appState.navigateBack()
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "chevron.left").font(.system(size: 12, weight: .semibold))
                    Text("Library").font(.system(size: 13))
                }
                .foregroundColor(.white.opacity(0.9))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.escape, modifiers: [])

            Spacer()

            Text(game.title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.white.opacity(0.85))
                .lineLimit(1)

            Spacer()
            Color.clear.frame(width: 90, height: 1)
        }
    }

    private var bottomBar: some View {
        HStack(spacing: 20) {
            // Save state
            hudButton(icon: "square.and.arrow.down", help: "Save State (⌘S)") {
                vm.saveState(game: game, library: library)
            }
            .keyboardShortcut("s", modifiers: .command)

            Spacer()

            // Pause / Resume
            hudButton(
                icon: vm.isPaused ? "play.fill" : "pause.fill",
                help: vm.isPaused ? "Resume (⌘P)" : "Pause (⌘P)",
                size: 20
            ) {
                vm.togglePause()
            }
            .keyboardShortcut("p", modifiers: .command)

            Spacer()

            // Load state
            hudButton(icon: "square.and.arrow.up", help: "Load Last State (⌘L)") {
                vm.loadLatestState(game: game)
            }
            .keyboardShortcut("l", modifiers: .command)
        }
    }

    private func hudButton(
        icon: String,
        help: String,
        size: CGFloat = 16,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: size))
                .foregroundColor(.white)
                .frame(width: 44, height: 44)
                .background(.white.opacity(0.15), in: Circle())
        }
        .buttonStyle(.plain)
        .help(help)
    }

    // MARK: - HUD auto-hide

    private func showHUD() {
        hideTask?.cancel()
        if !hudVisible { hudVisible = true }
        let task = DispatchWorkItem { hudVisible = false }
        hideTask = task
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0, execute: task)
    }
}
