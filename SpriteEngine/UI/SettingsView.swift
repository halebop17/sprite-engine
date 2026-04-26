import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {

    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var library: ROMLibrary
    @Environment(\.appTheme) private var t
    @State private var isScanning = false
    @State private var lastScanCount: Int? = nil

    var body: some View {
        VStack(spacing: 0) {
            topBar
            Divider().background(t.divider)
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    biosSection
                    romFoldersSection
                    videoSection
                    audioSection
                    emulationSection
                    appearanceSection
                }
                .padding(26)
                .frame(maxWidth: 760, alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .background(t.surface)
    }

    // MARK: - Top bar

    private var topBar: some View {
        HStack {
            BackButton()
            Spacer()
            Text("Settings")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(t.text)
            Spacer()
            Color.clear.frame(width: 60, height: 1)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(t.toolbar)
    }

    // MARK: - BIOS

    private var biosSection: some View {
        SettingsSection(title: "BIOS") {
            DirectoryRow(
                label: "BIOS Folder",
                detail: "neogeo.zip, qsound.zip",
                url: appState.biosDirectoryURL,
                pick: pickBIOS
            )
        }
    }

    // MARK: - ROM Folders

    private var romFoldersSection: some View {
        SettingsSection(title: "ROM FOLDERS") {
            ForEach(appState.romDirectoryURLs, id: \.self) { url in
                HStack(spacing: 10) {
                    Image(systemName: "folder")
                        .font(.system(size: 13))
                        .foregroundColor(t.accent)
                        .frame(width: 20)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(url.lastPathComponent)
                            .font(.system(size: 13))
                            .foregroundColor(t.text)
                        Text(url.path)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(t.textMuted)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    Spacer()
                    Button {
                        library.removeGames(inDirectory: url)
                        appState.removeROMDirectory(url)
                    } label: {
                        Image(systemName: "minus.circle.fill")
                            .font(.system(size: 15))
                            .foregroundColor(t.textFaint)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                Divider().background(t.divider).padding(.leading, 14)
            }
            // Add + Rescan row
            HStack(spacing: 0) {
                Button(action: pickROM) {
                    HStack(spacing: 8) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 15))
                            .foregroundColor(t.accent)
                        Text("Add ROM Folder…")
                            .font(.system(size: 13))
                            .foregroundColor(t.accent)
                        Spacer()
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                }
                .buttonStyle(.plain)
                if !appState.romDirectoryURLs.isEmpty {
                    Divider().background(t.divider).frame(width: 1, height: 36)
                    Button {
                        guard !isScanning else { return }
                        isScanning = true
                        lastScanCount = nil
                        let dirs = appState.romDirectoryURLs
                        Task {
                            await library.scan(directories: dirs)
                            await MainActor.run {
                                lastScanCount = library.games.count
                                isScanning = false
                            }
                        }
                    } label: {
                        HStack(spacing: 6) {
                            if isScanning {
                                ProgressView()
                                    .scaleEffect(0.65)
                                    .frame(width: 12, height: 12)
                                Text("Scanning…")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(t.accent)
                            } else {
                                Image(systemName: "arrow.clockwise")
                                    .font(.system(size: 11))
                                Text(lastScanCount.map { "\($0) found" } ?? "Rescan")
                                    .font(.system(size: 12, weight: .semibold))
                            }
                        }
                        .foregroundColor(isScanning ? t.accent : t.textMuted)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                    }
                    .buttonStyle(.plain)
                    .disabled(isScanning)
                }
            }
        }
    }

    // MARK: - Video

    private var videoSection: some View {
        SettingsSection(title: "VIDEO") {
            // Scale mode
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Scale Mode")
                        .font(.system(size: 13))
                        .foregroundColor(t.text)
                    Text("How the image fills the window")
                        .font(.system(size: 11))
                        .foregroundColor(t.textMuted)
                }
                Spacer()
                ThemedSegmentedPicker(
                    options: VideoScaleMode.allCases.map { (label: $0.label, value: $0) },
                    selection: Binding(
                        get: { appState.videoScaleMode },
                        set: { appState.setVideoScaleMode($0) }
                    )
                )
                .frame(width: 260)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)

            Divider().background(t.divider).padding(.leading, 14)

            ToggleRow(label: "CRT Filter",
                      detail: "Scanlines, phosphor glow, and vignette",
                      isOn: Binding(
                          get: { appState.videoCRTFilter },
                          set: { appState.setVideoCRTFilter($0) }
                      ))

            Divider().background(t.divider).padding(.leading, 14)

            ToggleRow(label: "Scanlines",
                      detail: "Overlay scanline effect (coming soon)",
                      isOn: Binding(
                          get: { appState.videoScanlines },
                          set: { appState.setVideoScanlines($0) }
                      ))
        }
    }

    // MARK: - Audio

    private var audioSection: some View {
        SettingsSection(title: "AUDIO") {
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Volume")
                        .font(.system(size: 13))
                        .foregroundColor(t.text)
                    Text(String(format: "%.0f%%", appState.audioVolume * 100))
                        .font(.system(size: 11))
                        .foregroundColor(t.textMuted)
                }
                .frame(width: 70, alignment: .leading)
                Slider(value: Binding(
                    get: { Double(appState.audioVolume) },
                    set: { appState.setAudioVolume(Float($0)) }
                ), in: 0...1)
                .accentColor(t.accent)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        }
    }

    // MARK: - Emulation

    private var emulationSection: some View {
        SettingsSection(title: "EMULATION") {
            ToggleRow(label: "Show FPS Overlay",
                      detail: "Display frame rate counter during play",
                      isOn: Binding(
                          get: { appState.showFPSOverlay },
                          set: { appState.setShowFPSOverlay($0) }
                      ))

            Divider().background(t.divider).padding(.leading, 14)

            Button {
                appState.navigate(to: .romVerifier)
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "checkmark.shield")
                        .font(.system(size: 13))
                        .foregroundColor(t.accent)
                        .frame(width: 20)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Verify ROM Set")
                            .font(.system(size: 13))
                            .foregroundColor(t.text)
                        Text("Check all library ROMs against FBNeo's file and CRC database")
                            .font(.system(size: 11))
                            .foregroundColor(t.textMuted)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11))
                        .foregroundColor(t.textFaint)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Appearance

    private var appearanceSection: some View {
        SettingsSection(title: "APPEARANCE") {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Theme")
                        .font(.system(size: 13))
                        .foregroundColor(t.text)
                    Text("App-wide colour scheme")
                        .font(.system(size: 11))
                        .foregroundColor(t.textMuted)
                }
                Spacer()
                ThemedSegmentedPicker(
                    options: [
                        (label: "Dark",      value: AppThemeKey.dark),
                        (label: "Light",     value: AppThemeKey.light),
                        (label: "CRT Amber", value: AppThemeKey.amber),
                    ],
                    selection: Binding(
                        get: { appState.themeKey },
                        set: { appState.setTheme($0) }
                    )
                )
                .frame(width: 260)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        }
    }

    // MARK: - Pickers

    private func pickBIOS() {
        let panel = NSOpenPanel()
        panel.title = "Choose BIOS Folder"
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            DispatchQueue.main.async { appState.setBIOSDirectory(url) }
        }
    }

    private func pickROM() {
        let panel = NSOpenPanel()
        panel.title = "Choose ROM Folder"
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            DispatchQueue.main.async {
                appState.addROMDirectory(url)
                isScanning = true
                lastScanCount = nil
                let dirs = appState.romDirectoryURLs
                Task {
                    await library.scan(directories: dirs)
                    await MainActor.run {
                        lastScanCount = library.games.count
                        isScanning = false
                    }
                }
            }
        }
    }
}

// MARK: - Section container

private struct SettingsSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content
    @Environment(\.appTheme) private var t

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(t.textFaint)
                .kerning(0.8)
            VStack(spacing: 0) {
                content
            }
            .background(t.card)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10)
                .strokeBorder(t.cardBorder, lineWidth: 1))
        }
    }
}

// MARK: - Toggle row

private struct ToggleRow: View {
    let label:  String
    let detail: String
    @Binding var isOn: Bool
    @Environment(\.appTheme) private var t

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: 13))
                    .foregroundColor(t.text)
                Text(detail)
                    .font(.system(size: 11))
                    .foregroundColor(t.textMuted)
            }
            Spacer()
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .toggleStyle(.switch)
                .tint(t.accent)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }
}

// MARK: - Directory row

private struct DirectoryRow: View {
    let label:  String
    let detail: String
    let url:    URL?
    let pick:   () -> Void
    @Environment(\.appTheme) private var t

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: 13))
                    .foregroundColor(t.text)
                if let url {
                    Text(url.path)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(t.accent)
                        .lineLimit(1)
                        .truncationMode(.middle)
                } else {
                    Text(detail)
                        .font(.system(size: 11))
                        .foregroundColor(t.textMuted)
                }
            }
            Spacer()
            Button("Choose…", action: pick)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(t.text)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(t.card)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay(RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(t.cardBorder, lineWidth: 1))
                .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }
}
