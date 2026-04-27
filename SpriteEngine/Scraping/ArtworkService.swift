import Foundation
import AppKit

@MainActor
final class ArtworkService: ObservableObject {

    static let shared = ArtworkService()

    enum Status: Equatable {
        case idle
        case scraping
        case done
        case notFound
        case error(String)
        case skipped       // manual cover present
    }

    /// Per-game status, observable so the bulk-scrape modal can render progress.
    @Published private(set) var statuses: [UUID: Status] = [:]
    @Published private(set) var inFlight: Set<UUID> = []

    private let scraper = ArtworkScraper.shared
    /// Serialises ScreenScraper API calls (level-1 dev = 1 thread).
    private var apiQueue: Task<Void, Never>?

    private init() {}

    // MARK: - Public

    func status(for gameID: UUID) -> Status {
        statuses[gameID] ?? .idle
    }

    /// Scrapes one game end-to-end (jeuInfos → eager downloads → mark library).
    /// Returns true if at least the box art was saved.
    @discardableResult
    func scrapeOne(_ game: Game,
                   library: ROMLibrary,
                   force: Bool = false) async -> Bool {

        if !force, game.coverIsManual {
            statuses[game.id] = .skipped
            return false
        }

        let creds = readCredentials()
        guard !creds.user.isEmpty, !creds.pass.isEmpty else {
            statuses[game.id] = .error("ScreenScraper credentials not set")
            return false
        }

        statuses[game.id] = .scraping
        inFlight.insert(game.id)
        defer { inFlight.remove(game.id) }

        let scraped: ScrapedArtwork
        do {
            scraped = try await scraper.lookup(romURL: game.romURL,
                                               system: game.system,
                                               ssid: creds.user,
                                               sspassword: creds.pass,
                                               nameOverride: game.scrapeNameOverride)
        } catch ScraperError.notFound {
            statuses[game.id] = .notFound
            return false
        } catch {
            statuses[game.id] = .error(error.localizedDescription)
            return false
        }

        // Persist all media URLs so the Media tab can lazily download extras
        // without re-calling jeuInfos.php.
        ArtworkCache.saveMetadata(scraped, for: game.id)

        // Eager downloads: box, wheel, marquee. Run in parallel.
        async let boxData     = downloadOptional(scraped.boxArtURL)
        async let wheelData   = downloadOptional(scraped.wheelURL)
        async let marqueeData = downloadOptional(scraped.marqueeURL)
        let (box, wheel, marquee) = await (boxData, wheelData, marqueeData)

        var savedCover = false
        if let data = box, !data.isEmpty {
            ArtworkCache.save(data, for: game.id, kind: .boxArt, ext: imageExt(for: data))
            savedCover = true
        }
        if let data = wheel, !data.isEmpty {
            ArtworkCache.save(data, for: game.id, kind: .wheel, ext: imageExt(for: data))
        }
        if let data = marquee, !data.isEmpty {
            ArtworkCache.save(data, for: game.id, kind: .marquee, ext: imageExt(for: data))
        }

        if savedCover {
            library.markArtworkPresent(game.id, manual: false)
            statuses[game.id] = .done
            return true
        } else {
            statuses[game.id] = .notFound
            return false
        }
    }

    /// Downloads the secondary media (back box, 3D box, fanart, title screen,
    /// support art, bezel, screenshots) using the metadata.json cached during
    /// the eager scrape. No new ScreenScraper API call is made.
    @discardableResult
    func fetchExtras(for game: Game) async -> Bool {
        guard let meta = ArtworkCache.loadMetadata(for: game.id) else { return false }
        var any = false

        async let backData    = downloadIfMissing(meta.boxBackURL,     game: game, kind: .boxBack)
        async let box3DData   = downloadIfMissing(meta.box3DURL,       game: game, kind: .box3D)
        async let fanartData  = downloadIfMissing(meta.fanartURL,      game: game, kind: .fanart)
        async let titleData   = downloadIfMissing(meta.titleScreenURL, game: game, kind: .titleScreen)
        async let supportData = downloadIfMissing(meta.supportURL,     game: game, kind: .support)
        async let bezelData   = downloadIfMissing(meta.bezelURL,       game: game, kind: .bezel)

        let (a, b, c, d, e, f) = await (backData, box3DData, fanartData,
                                        titleData, supportData, bezelData)
        any = a || b || c || d || e || f

        // Screenshots — limit to first 8 to keep cache reasonable.
        for (idx, url) in meta.screenshotURLs.prefix(8).enumerated() {
            let target = ArtworkCache.screenshotURL(for: game.id, index: idx)
            if FileManager.default.fileExists(atPath: target.path) { continue }
            if let data = try? await scraper.downloadImage(at: url), !data.isEmpty {
                try? data.write(to: target, options: .atomic)
                any = true
            }
        }
        return any
    }

    private func downloadIfMissing(_ url: URL?, game: Game, kind: ArtworkKind) async -> Bool {
        guard let url else { return false }
        if ArtworkCache.existingFile(for: game.id, kind: kind) != nil { return false }
        guard let data = try? await scraper.downloadImage(at: url), !data.isEmpty else { return false }
        ArtworkCache.save(data, for: game.id, kind: kind, ext: imageExt(for: data))
        return true
    }

    /// Bulk scrape: queues every game lacking artwork (or all, with `force`).
    /// API calls are serialised; image downloads inside each scrape run in parallel.
    func scrapeMany(_ games: [Game], library: ROMLibrary, force: Bool = false) {
        let targets = force ? games : games.filter { !$0.hasArtwork }
        guard !targets.isEmpty else { return }

        // Cancel any prior bulk run.
        apiQueue?.cancel()
        for g in targets where statuses[g.id] != .done {
            statuses[g.id] = .idle
        }

        apiQueue = Task { [weak self] in
            guard let self else { return }
            for game in targets {
                if Task.isCancelled { break }
                _ = await self.scrapeOne(game, library: library, force: force)
            }
        }
    }

    func cancelBulk() { apiQueue?.cancel() }

    /// Manual override — copies a user-picked file into the cache as box art.
    func setManualCover(from sourceURL: URL,
                        for game: Game,
                        library: ROMLibrary) -> Bool {
        guard let img = NSImage(contentsOf: sourceURL),
              let data = jpegData(from: img) else { return false }
        ArtworkCache.save(data, for: game.id, kind: .boxArt, ext: "jpg")
        library.markArtworkPresent(game.id, manual: true)
        statuses[game.id] = .done
        return true
    }

    // MARK: - Internals

    private func readCredentials() -> (user: String, pass: String) {
        let ud = UserDefaults.standard
        return (ud.string(forKey: "screenScraperUsername") ?? "",
                ud.string(forKey: "screenScraperPassword") ?? "")
    }

    private func downloadOptional(_ url: URL?) async -> Data? {
        guard let url else { return nil }
        return try? await scraper.downloadImage(at: url)
    }

    private func imageExt(for data: Data) -> String {
        // PNG: 89 50 4E 47 ; JPEG: FF D8 FF
        if data.count >= 4,
           data[0] == 0x89, data[1] == 0x50, data[2] == 0x4E, data[3] == 0x47 {
            return "png"
        }
        return "jpg"
    }

    private func jpegData(from image: NSImage) -> Data? {
        guard let tiff = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff) else { return nil }
        return bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.92])
    }
}
