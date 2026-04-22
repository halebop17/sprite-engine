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

    init() {
        if let raw = UserDefaults.standard.string(forKey: "themeKey"),
           let key = AppThemeKey(rawValue: raw) { themeKey = key }
        if let path = UserDefaults.standard.string(forKey: "biosDirectoryPath") {
            let url = URL(fileURLWithPath: path, isDirectory: true)
            if FileManager.default.fileExists(atPath: path) { biosDirectoryURL = url }
        }
        if let path = UserDefaults.standard.string(forKey: "romDirectoryPath") {
            let url = URL(fileURLWithPath: path, isDirectory: true)
            if FileManager.default.fileExists(atPath: path) { romDirectoryURL = url }
        }
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

    // MARK: BIOS validation

    var isBIOSPresent: Bool {
        guard let dir = biosDirectoryURL else { return false }
        let fm = FileManager.default
        return ["neogeo.zip", "aes.zip", "qsound.zip"].contains {
            fm.fileExists(atPath: dir.appendingPathComponent($0).path)
        }
    }
}
