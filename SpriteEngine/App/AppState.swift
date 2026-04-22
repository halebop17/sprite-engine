import Foundation
import SwiftUI

// MARK: - Screen

enum Screen: Equatable {
    case library
    case detail(Game)
    case `import`
    case settings
    case emulator(Game)
}

// MARK: - AppState

@MainActor
final class AppState: ObservableObject {

    @Published var screen: Screen = .library
    @Published var biosDirectoryURL: URL?
    @Published var romDirectoryURL:  URL?
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
        if let path = ud.string(forKey: "romDirectoryPath") {
            let url = URL(fileURLWithPath: path, isDirectory: true)
            if FileManager.default.fileExists(atPath: path) { romDirectoryURL = url }
        }
        if let raw = ud.string(forKey: "videoScaleMode"),
           let mode = VideoScaleMode(rawValue: raw) { videoScaleMode = mode }
        videoScanlines  = ud.bool(forKey: "videoScanlines")
        videoCRTFilter  = ud.bool(forKey: "videoCRTFilter")
        if ud.object(forKey: "audioVolume") != nil {
            audioVolume = ud.float(forKey: "audioVolume")
        }
        showFPSOverlay  = ud.bool(forKey: "showFPSOverlay")
    }

    // MARK: Navigation

    func navigate(to screen: Screen) { self.screen = screen }
    func navigateBack()               { screen = .library }

    // MARK: Directory persistence

    func setTheme(_ key: AppThemeKey) {
        themeKey = key
        UserDefaults.standard.set(key.rawValue, forKey: "themeKey")
    }

    func setBIOSDirectory(_ url: URL) {
        biosDirectoryURL = url
        UserDefaults.standard.set(url.path, forKey: "biosDirectoryPath")
    }

    func setROMDirectory(_ url: URL) {
        romDirectoryURL = url
        UserDefaults.standard.set(url.path, forKey: "romDirectoryPath")
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
