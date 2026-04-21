import SwiftUI
import MetalKit
import AppKit
import UniformTypeIdentifiers

// MARK: - ViewModel

@MainActor
final class PlaybackViewModel: ObservableObject {

    let emulatorView   = EmulatorView(frame: .zero, device: MTLCreateSystemDefaultDevice())
    let inputManager   = InputManager()

    @Published var isRunning    = false
    @Published var errorMessage: String?
    @Published var biosDirectoryURL: URL?

    private var session: EmulatorSession?

    init() {
        if let path = UserDefaults.standard.string(forKey: "biosDirectoryPath") {
            let url = URL(fileURLWithPath: path, isDirectory: true)
            if FileManager.default.fileExists(atPath: path) {
                biosDirectoryURL = url
            }
        }
        inputManager.startControllerDiscovery()
        emulatorView.inputManager = inputManager
    }

    // MARK: - BIOS directory

    func selectBIOSDirectory(completion: (() -> Void)? = nil) {
        let panel = NSOpenPanel()
        panel.title = "Select BIOS Folder"
        panel.message = "Choose the folder containing neogeo.zip / aes.zip"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.begin { [weak self] response in
            guard response == .OK, let url = panel.url else { return }
            self?.biosDirectoryURL = url
            UserDefaults.standard.set(url.path, forKey: "biosDirectoryPath")
            completion?()
        }
    }

    // MARK: - ROM loading

    func openROM(url: URL) {
        guard let biosDir = biosDirectoryURL else {
            selectBIOSDirectory { [weak self] in self?.openROM(url: url) }
            return
        }

        let system: EmulatorSystem
        switch url.pathExtension.lowercased() {
        case "neo":  system = .neoGeoAES
        default:
            errorMessage = EmulatorError.unsupportedFormat(url.pathExtension).localizedDescription
            return
        }

        stopSession()

        let core = GeolithCore(system: system)
        do {
            try core.loadROM(at: url, biosDirectory: biosDir)
        } catch {
            errorMessage = error.localizedDescription
            return
        }

        let s = EmulatorSession(core: core)

        // Frame delivery
        s.onFrameReady = { [weak self, weak s] in
            guard let self, let s else { return }
            s.withFrontBuffer { pixels, w, h in
                self.emulatorView.update(pixels: pixels, width: w, height: h)
            }
        }

        // Input delivery
        inputManager.onInputChanged = { [weak s] player, buttons in
            s?.setInput(player: player, buttons: buttons)
        }
        inputManager.onSysInputChanged = { [weak s] buttons in
            s?.setSysInput(buttons)
        }

        session = s
        isRunning = true
        s.start()
    }

    // MARK: - Stop

    func stopSession() {
        session?.stop()
        session = nil
        inputManager.onInputChanged    = nil
        inputManager.onSysInputChanged = nil
        isRunning = false
    }
}

// MARK: - View

struct ContentView: View {

    @StateObject private var vm = PlaybackViewModel()
    @State private var showROMPicker = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            EmulatorViewRepresentable(emulatorView: vm.emulatorView)

            if !vm.isRunning {
                launchOverlay
            }
        }
        .frame(minWidth: 640, minHeight: 480)
        .onChange(of: vm.isRunning) { running in
            if running {
                // Give the Metal view keyboard focus as soon as a game starts.
                vm.emulatorView.window?.makeFirstResponder(vm.emulatorView)
            }
        }
        .fileImporter(isPresented: $showROMPicker,
                      allowedContentTypes: [.data],
                      onCompletion: { result in
            if case .success(let url) = result {
                _ = url.startAccessingSecurityScopedResource()
                vm.openROM(url: url)
            }
        })
        .alert("Error",
               isPresented: Binding(get: { vm.errorMessage != nil },
                                    set: { if !$0 { vm.errorMessage = nil } }),
               actions: { Button("OK") { vm.errorMessage = nil } },
               message: { Text(vm.errorMessage ?? "") })
    }

    @ViewBuilder
    private var launchOverlay: some View {
        VStack(spacing: 24) {
            Text("Sprite Engine")
                .font(.system(size: 40, weight: .bold, design: .rounded))
                .foregroundColor(.white)

            HStack(spacing: 16) {
                Button("Set BIOS Folder") {
                    vm.selectBIOSDirectory()
                }
                .buttonStyle(.bordered)

                Button("Open .neo ROM") {
                    if vm.biosDirectoryURL == nil {
                        vm.selectBIOSDirectory { showROMPicker = true }
                    } else {
                        showROMPicker = true
                    }
                }
                .buttonStyle(.borderedProminent)
            }

            if let biosDir = vm.biosDirectoryURL {
                Text("BIOS: \(biosDir.lastPathComponent)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(32)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
}
