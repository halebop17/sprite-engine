import Foundation
import AppKit

enum ArtworkKind: String, CaseIterable {
    case boxArt    = "box"
    case wheel     = "wheel"
    case marquee   = "marquee"
    case boxBack   = "boxback"
    case box3D     = "box3d"
    case fanart    = "fanart"
    case titleScreen = "title"
    case support   = "support"
    case bezel     = "bezel"

    var displayLabel: String {
        switch self {
        case .boxArt:      return "Box Art"
        case .wheel:       return "Logo / Wheel"
        case .marquee:     return "Marquee"
        case .boxBack:     return "Back Cover"
        case .box3D:       return "3D Box"
        case .fanart:      return "Fan Art"
        case .titleScreen: return "Title Screen"
        case .support:     return "Cartridge / CD"
        case .bezel:       return "Arcade Bezel"
        }
    }
}

enum ArtworkCache {

    // MARK: Paths

    static func cacheDirectory(for gameID: UUID) -> URL {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = support
            .appendingPathComponent("SpriteEngine", isDirectory: true)
            .appendingPathComponent("Artwork", isDirectory: true)
            .appendingPathComponent(gameID.uuidString, isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    static func fileURL(for gameID: UUID, kind: ArtworkKind, ext: String = "jpg") -> URL {
        cacheDirectory(for: gameID).appendingPathComponent("\(kind.rawValue).\(ext)")
    }

    static func screenshotURL(for gameID: UUID, index: Int, ext: String = "jpg") -> URL {
        cacheDirectory(for: gameID).appendingPathComponent("screenshot_\(index).\(ext)")
    }

    static func metadataURL(for gameID: UUID) -> URL {
        cacheDirectory(for: gameID).appendingPathComponent("metadata.json")
    }

    // MARK: Metadata persistence

    static func saveMetadata(_ artwork: ScrapedArtwork, for gameID: UUID) {
        guard let data = try? JSONEncoder().encode(artwork) else { return }
        try? data.write(to: metadataURL(for: gameID), options: .atomic)
    }

    static func loadMetadata(for gameID: UUID) -> ScrapedArtwork? {
        let url = metadataURL(for: gameID)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(ScrapedArtwork.self, from: data)
    }

    // MARK: Generic lookup

    static func existingFile(for gameID: UUID, kind: ArtworkKind) -> URL? {
        let dir = cacheDirectory(for: gameID)
        for ext in ["jpg", "png"] {
            let url = dir.appendingPathComponent("\(kind.rawValue).\(ext)")
            if FileManager.default.fileExists(atPath: url.path) { return url }
        }
        return nil
    }

    static func image(for gameID: UUID, kind: ArtworkKind) -> NSImage? {
        guard let url = existingFile(for: gameID, kind: kind) else { return nil }
        return NSImage(contentsOf: url)
    }

    /// Lists every cached image entry for a game, including extras and screenshots.
    static func allCached(for gameID: UUID) -> [(label: String, kind: ArtworkKind?, url: URL, isScreenshot: Bool)] {
        let dir = cacheDirectory(for: gameID)
        guard let entries = try? FileManager.default.contentsOfDirectory(
            at: dir,
            includingPropertiesForKeys: nil
        ) else { return [] }

        var out: [(label: String, kind: ArtworkKind?, url: URL, isScreenshot: Bool)] = []
        for url in entries {
            let name = url.deletingPathExtension().lastPathComponent
            let ext  = url.pathExtension.lowercased()
            guard ["jpg", "jpeg", "png"].contains(ext) else { continue }

            if name.hasPrefix("screenshot_") {
                let idx = name.replacingOccurrences(of: "screenshot_", with: "")
                out.append((label: "Screenshot \(Int(idx).map { String($0 + 1) } ?? idx)",
                            kind: nil,
                            url: url,
                            isScreenshot: true))
            } else if let kind = ArtworkKind(rawValue: name) {
                out.append((label: kind.displayLabel,
                            kind: kind,
                            url: url,
                            isScreenshot: false))
            }
        }
        // Stable order: declared ArtworkKind order, then screenshots by index.
        let kindOrder = Dictionary(uniqueKeysWithValues:
            ArtworkKind.allCases.enumerated().map { ($0.element.rawValue, $0.offset) })
        out.sort { lhs, rhs in
            if lhs.isScreenshot && rhs.isScreenshot {
                return lhs.url.lastPathComponent < rhs.url.lastPathComponent
            }
            if lhs.isScreenshot != rhs.isScreenshot {
                return !lhs.isScreenshot
            }
            let li = lhs.kind.flatMap { kindOrder[$0.rawValue] } ?? Int.max
            let ri = rhs.kind.flatMap { kindOrder[$0.rawValue] } ?? Int.max
            return li < ri
        }
        return out
    }

    // MARK: Existence

    static func hasBoxArt(for gameID: UUID) -> Bool {
        let dir = cacheDirectory(for: gameID)
        for ext in ["jpg", "png"] {
            let path = dir.appendingPathComponent("box.\(ext)").path
            if FileManager.default.fileExists(atPath: path) { return true }
        }
        return false
    }

    // MARK: Reads

    static func boxArt(for gameID: UUID) -> NSImage? {
        return loadImage(in: cacheDirectory(for: gameID), basename: "box")
    }

    static func wheel(for gameID: UUID) -> NSImage? {
        return loadImage(in: cacheDirectory(for: gameID), basename: "wheel")
    }

    static func marquee(for gameID: UUID) -> NSImage? {
        return loadImage(in: cacheDirectory(for: gameID), basename: "marquee")
    }

    // MARK: Writes

    static func save(_ data: Data, for gameID: UUID, kind: ArtworkKind, ext: String = "jpg") {
        let url = fileURL(for: gameID, kind: kind, ext: ext)
        try? data.write(to: url, options: .atomic)
    }

    static func saveScreenshot(_ data: Data, for gameID: UUID, index: Int, ext: String = "jpg") {
        let url = screenshotURL(for: gameID, index: index, ext: ext)
        try? data.write(to: url, options: .atomic)
    }

    // MARK: Clear

    static func clear(for gameID: UUID) {
        try? FileManager.default.removeItem(at: cacheDirectory(for: gameID))
    }

    // MARK: Private

    private static func loadImage(in dir: URL, basename: String) -> NSImage? {
        for ext in ["jpg", "png"] {
            let path = dir.appendingPathComponent("\(basename).\(ext)").path
            if let img = NSImage(contentsOfFile: path) { return img }
        }
        return nil
    }
}
