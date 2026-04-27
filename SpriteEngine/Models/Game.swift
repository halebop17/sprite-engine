import Foundation

struct Game: Identifiable, Codable, Equatable {
    let id: UUID
    let title: String
    let system: EmulatorSystem
    let romURL: URL
    let artworkURL: URL?
    var lastPlayed: Date?
    var isFavorite: Bool
    var saveStates: [SaveState]

    /// True once box art has been written to disk for this game (scraped or
    /// manually picked). Drives whether the card shows real art or the
    /// generated placeholder.
    var hasArtwork: Bool

    /// True if the user explicitly chose the cover image (Set Cover Image…
    /// or "Set as Cover" in the Media tab). Re-scraping won't overwrite a
    /// manually-picked cover without confirmation.
    var coverIsManual: Bool

    /// Optional override sent to ScreenScraper as `romnom` instead of the real
    /// filename. Useful when the on-disk name is unusual ("TMNT (USA).zip")
    /// but ScreenScraper indexes it under a different short name ("tmnt.zip").
    var scrapeNameOverride: String?

    init(
        id: UUID,
        title: String,
        system: EmulatorSystem,
        romURL: URL,
        artworkURL: URL? = nil,
        lastPlayed: Date? = nil,
        isFavorite: Bool = false,
        saveStates: [SaveState] = [],
        hasArtwork: Bool = false,
        coverIsManual: Bool = false,
        scrapeNameOverride: String? = nil
    ) {
        self.id = id
        self.title = title
        self.system = system
        self.romURL = romURL
        self.artworkURL = artworkURL
        self.lastPlayed = lastPlayed
        self.isFavorite = isFavorite
        self.saveStates = saveStates
        self.hasArtwork = hasArtwork
        self.coverIsManual = coverIsManual
        self.scrapeNameOverride = scrapeNameOverride
    }

    private enum CodingKeys: String, CodingKey {
        case id, title, system, romURL, artworkURL, lastPlayed, isFavorite, saveStates
        case hasArtwork, coverIsManual, scrapeNameOverride
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id           = try c.decode(UUID.self, forKey: .id)
        title        = try c.decode(String.self, forKey: .title)
        system       = try c.decode(EmulatorSystem.self, forKey: .system)
        romURL       = try c.decode(URL.self, forKey: .romURL)
        artworkURL   = try c.decodeIfPresent(URL.self, forKey: .artworkURL)
        lastPlayed   = try c.decodeIfPresent(Date.self, forKey: .lastPlayed)
        isFavorite   = try c.decode(Bool.self, forKey: .isFavorite)
        saveStates   = try c.decode([SaveState].self, forKey: .saveStates)
        hasArtwork   = (try? c.decode(Bool.self, forKey: .hasArtwork)) ?? false
        coverIsManual = (try? c.decode(Bool.self, forKey: .coverIsManual)) ?? false
        scrapeNameOverride = try? c.decodeIfPresent(String.self, forKey: .scrapeNameOverride)
    }
}
