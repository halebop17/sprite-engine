import Foundation
import AppKit
import CoreGraphics

enum SaveStateManager {

    private static var baseURL: URL {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return support.appendingPathComponent("SpriteEngine/SaveStates", isDirectory: true)
    }

    // MARK: - Save

    static func save(
        game: Game,
        session: EmulatorSession,
        thumbnailPixels: [UInt32],
        thumbnailWidth: Int,
        thumbnailHeight: Int
    ) throws -> SaveState {
        let stateData = try session.saveState()

        let dir = baseURL.appendingPathComponent(game.id.uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        let id       = UUID()
        let dataURL  = dir.appendingPathComponent("\(id.uuidString).state")
        let thumbURL = dir.appendingPathComponent("\(id.uuidString).png")

        try stateData.write(to: dataURL, options: .atomic)

        if !thumbnailPixels.isEmpty,
           let png = makePNG(pixels: thumbnailPixels, width: thumbnailWidth, height: thumbnailHeight) {
            try png.write(to: thumbURL, options: .atomic)
        }

        return SaveState(
            id:           id,
            gameName:     game.title,
            system:       game.system,
            createdAt:    Date(),
            dataURL:      dataURL,
            thumbnailURL: thumbURL)
    }

    // MARK: - Load

    static func load(_ saveState: SaveState, into session: EmulatorSession) throws {
        let data = try Data(contentsOf: saveState.dataURL)
        try session.loadState(data)
    }

    // MARK: - Delete

    static func delete(_ saveState: SaveState) {
        try? FileManager.default.removeItem(at: saveState.dataURL)
        try? FileManager.default.removeItem(at: saveState.thumbnailURL)
    }

    // MARK: - Thumbnail image helper (for UI)

    static func thumbnail(for saveState: SaveState) -> NSImage? {
        guard FileManager.default.fileExists(atPath: saveState.thumbnailURL.path) else { return nil }
        return NSImage(contentsOf: saveState.thumbnailURL)
    }

    // MARK: - PNG generation from BGRA framebuffer

    private static func makePNG(pixels: [UInt32], width: Int, height: Int) -> Data? {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue:
            CGImageAlphaInfo.noneSkipFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue)

        let data = pixels.withUnsafeBytes { Data($0) }
        guard let provider = CGDataProvider(data: data as CFData),
              let cgImage  = CGImage(
                  width: width, height: height,
                  bitsPerComponent: 8, bitsPerPixel: 32,
                  bytesPerRow: width * 4,
                  space: colorSpace, bitmapInfo: bitmapInfo,
                  provider: provider, decode: nil,
                  shouldInterpolate: false, intent: .defaultIntent)
        else { return nil }

        let nsImage = NSImage(cgImage: cgImage, size: CGSize(width: width, height: height))
        guard let tiff = nsImage.tiffRepresentation,
              let rep  = NSBitmapImageRep(data: tiff)
        else { return nil }
        return rep.representation(using: .png, properties: [:])
    }
}
