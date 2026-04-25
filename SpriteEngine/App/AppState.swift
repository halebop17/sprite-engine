import Foundation
import SwiftUI

// MARK: - Screen

enum Screen: Equatable {
    case onboarding
    case library
    case detail(Game)
    case `import`
    case settings
    case romVerifier
    case emulator(Game)
}

// MARK: - AppState

@MainActor
final class AppState: ObservableObject {

    @Published var screen: Screen = .library
    @Published var hasCompletedOnboarding: Bool = false
    @Published var biosDirectoryURL: URL?
    @Published var romDirectoryURLs: [URL] = []
    @Published var themeKey: AppThemeKey = .dark

    // Video
    @Published var videoScaleMode: VideoScaleMode = .aspectFit
    @Published var videoScanlines: Bool = false
    @Published var videoCRTFilter: Bool = false

    // Audio
    @Published var audioVolume: Float = 1.0

    // Emulation
    @Published var showFPSOverlay: Bool = false

    init() {
        let ud = UserDefaults.standard
        if let raw = ud.string(forKey: "themeKey"),
           let key = AppThemeKey(rawValue: raw) { themeKey = key }
        if let path = ud.string(forKey: "biosDirectoryPath") {
            let url = URL(fileURLWithPath: path, isDirectory: true)
            if FileManager.default.fileExists(atPath: path) { biosDirectoryURL = url }
        }
        if let data = ud.data(forKey: "romDirectoryPaths"),
           let paths = try? JSONDecoder().decode([String].self, from: data) {
            romDirectoryURLs = paths.compactMap { path in
                let url = URL(fileURLWithPath: path, isDirectory: true)
                return FileManager.default.fileExists(atPath: path) ? url : nil
            }
        } else if let path = ud.string(forKey: "romDirectoryPath") {
            // migrate legacy single-path key
            let url = URL(fileURLWithPath: path, isDirectory: true)
            if FileManager.default.fileExists(atPath: path) {
                romDirectoryURLs = [url]
                persistROMDirectories()
            }
        }
        if let raw = ud.string(forKey: "videoScaleMode"),
           let mode = VideoScaleMode(rawValue: raw) { videoScaleMode = mode }
        videoScanlines  = ud.bool(forKey: "videoScanlines")
        videoCRTFilter  = ud.bool(forKey: "videoCRTFilter")
        if ud.object(forKey: "audioVolume") != nil {
            audioVolume = ud.float(forKey: "audioVolume")
        }
        showFPSOverlay        = ud.bool(forKey: "showFPSOverlay")
        hasCompletedOnboarding = ud.bool(forKey: "hasCompletedOnboarding")
        if !hasCompletedOnboarding { screen = .onboarding }
    }

    // MARK: Navigation

    func navigate(to screen: Screen) { self.screen = screen }
    func navigateBack()               { screen = .library }

    func completeOnboarding() {
        hasCompletedOnboarding = true
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
        screen = .library
    }

    // MARK: Directory persistence

    func setTheme(_ key: AppThemeKey) {
        themeKey = key
        UserDefaults.standard.set(key.rawValue, forKey: "themeKey")
    }

    func setBIOSDirectory(_ url: URL) {
        biosDirectoryURL = url
        UserDefaults.standard.set(url.path, forKey: "biosDirectoryPath")
    }

    func addROMDirectory(_ url: URL) {
        guard !romDirectoryURLs.contains(url) else { return }
        romDirectoryURLs.append(url)
        persistROMDirectories()
    }

    func removeROMDirectory(_ url: URL) {
        romDirectoryURLs.removeAll { $0 == url }
        persistROMDirectories()
    }

    private func persistROMDirectories() {
        let paths = romDirectoryURLs.map(\.path)
        if let data = try? JSONEncoder().encode(paths) {
            UserDefaults.standard.set(data, forKey: "romDirectoryPaths")
        }
    }

    // MARK: Settings persistence

    func setVideoScaleMode(_ mode: VideoScaleMode) {
        videoScaleMode = mode
        UserDefaults.standard.set(mode.rawValue, forKey: "videoScaleMode")
    }

    func setVideoScanlines(_ on: Bool) {
        videoScanlines = on
        UserDefaults.standard.set(on, forKey: "videoScanlines")
    }

    func setVideoCRTFilter(_ on: Bool) {
        videoCRTFilter = on
        UserDefaults.standard.set(on, forKey: "videoCRTFilter")
    }

    func setAudioVolume(_ v: Float) {
        audioVolume = v
        UserDefaults.standard.set(v, forKey: "audioVolume")
    }

    func setShowFPSOverlay(_ on: Bool) {
        showFPSOverlay = on
        UserDefaults.standard.set(on, forKey: "showFPSOverlay")
    }

    // MARK: BIOS validation

    var isBIOSPresent: Bool {
        guard let dir = biosDirectoryURL else { return false }
        let fm = FileManager.default
        return ["neogeo.zip", "aes.zip", "qsound.zip"].contains {
            fm.fileExists(atPath: dir.appendingPathComponent($0).path)
        }
    }
}
