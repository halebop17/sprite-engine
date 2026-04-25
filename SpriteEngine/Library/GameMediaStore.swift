import Foundation
import AppKit

enum GameMediaStore {

    static func mediaDirectory(for gameID: UUID) -> URL {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = support
            .appendingPathComponent("SpriteEngine", isDirectory: true)
            .appendingPathComponent("Media", isDirectory: true)
            .appendingPathComponent(gameID.uuidString, isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    // MARK: - Index

    static func load(for gameID: UUID) -> [GameMediaItem] {
        let url = indexURL(gameID)
        guard
            let data = try? Data(contentsOf: url),
            let items = try? JSONDecoder().decode([GameMediaItem].self, from: data)
        else { return [] }
        return items.filter {
            FileManager.default.fileExists(atPath: mediaDirectory(for: gameID).appendingPathComponent($0.filename).path)
        }
    }

    static func save(_ items: [GameMediaItem], for gameID: UUID) {
        guard let data = try? JSONEncoder().encode(items) else { return }
        try? data.write(to: indexURL(gameID), options: .atomic)
    }

    // MARK: - Add

    static func addItem(sourceURL: URL, kind: GameMediaKind, label: String, gameID: UUID) -> GameMediaItem? {
        let ext = sourceURL.pathExtension
        let filename = "\(UUID().uuidString).\(ext)"
        let dest = mediaDirectory(for: gameID).appendingPathComponent(filename)
        do {
            try FileManager.default.copyItem(at: sourceURL, to: dest)
            return GameMediaItem(kind: kind, label: label, filename: filename)
        } catch {
            return nil
        }
    }

    // MARK: - Delete

    static func delete(_ item: GameMediaItem, gameID: UUID) {
        let path = mediaDirectory(for: gameID).appendingPathComponent(item.filename)
        try? FileManager.default.removeItem(at: path)
    }

    // MARK: - File access

    static func url(for item: GameMediaItem, gameID: UUID) -> URL {
        mediaDirectory(for: gameID).appendingPathComponent(item.filename)
    }

    static func image(for item: GameMediaItem, gameID: UUID) -> NSImage? {
        guard item.kind == .image else { return nil }
        let path = mediaDirectory(for: gameID).appendingPathComponent(item.filename).path
        return NSImage(contentsOfFile: path)
    }

    static func fileSize(for item: GameMediaItem, gameID: UUID) -> String {
        let path = mediaDirectory(for: gameID).appendingPathComponent(item.filename)
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: path.path),
              let size = attrs[.size] as? Int64 else { return "" }
        return ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }

    // MARK: - Private

    private static func indexURL(_ gameID: UUID) -> URL {
        mediaDirectory(for: gameID).appendingPathComponent("index.json")
    }
}
