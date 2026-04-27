import Foundation

// MARK: - Public types

struct ScraperUserInfo {
    let id: String
    let level: String?
    let contribution: String?
    let maxThreads: Int
    let maxRequestsPerDay: Int
    let maxRequestsPerMin: Int
    let requestsToday: Int
    let favRegion: String?
    let favLanguage: String?
}

struct ScrapedArtwork: Codable {
    let title: String
    let boxArtURL: URL?
    let wheelURL: URL?
    let marqueeURL: URL?
    let boxBackURL: URL?
    let box3DURL: URL?
    let fanartURL: URL?
    let titleScreenURL: URL?
    let supportURL: URL?
    let bezelURL: URL?
    let screenshotURLs: [URL]
}

enum ScraperError: Error, LocalizedError {
    case missingDevCredentials
    case missingUserCredentials
    case fileUnreadable(URL)
    case invalidResponse
    case apiClosed(String)
    case authFailed(String)
    case quotaExceeded(String)
    case notFound(String)
    case http(Int, String)

    var errorDescription: String? {
        switch self {
        case .missingDevCredentials:
            return "ScreenScraper developer credentials are not configured. Edit Secrets.swift."
        case .missingUserCredentials:
            return "Enter your ScreenScraper username and password in Settings."
        case .fileUnreadable(let url):
            return "Could not read ROM file at \(url.lastPathComponent)."
        case .invalidResponse:
            return "ScreenScraper returned an unexpected response."
        case .apiClosed(let msg):
            return "ScreenScraper API is currently closed: \(msg)"
        case .authFailed(let msg):
            return "Login failed: \(msg)"
        case .quotaExceeded(let msg):
            return "Daily quota exceeded: \(msg)"
        case .notFound(let name):
            return "No match found for \(name)."
        case .http(let code, let msg):
            return "HTTP \(code): \(msg)"
        }
    }
}

// MARK: - Scraper

actor ArtworkScraper {

    static let shared = ArtworkScraper()

    private let session: URLSession
    private let baseURL = URL(string: "https://api.screenscraper.fr/api2/")!
    private var lastRequestStartedAt: Date = .distantPast
    private let minRequestSpacing: TimeInterval = 1.0

    private init() {
        let cfg = URLSessionConfiguration.default
        cfg.timeoutIntervalForRequest = 20
        cfg.timeoutIntervalForResource = 60
        cfg.waitsForConnectivity = true
        session = URLSession(configuration: cfg)
    }

    // MARK: Public API

    /// Validates the supplied user credentials and returns quota info on success.
    func testConnection(ssid: String, sspassword: String) async throws -> ScraperUserInfo {
        guard ScreenScraperSecrets.isConfigured else { throw ScraperError.missingDevCredentials }
        let trimmedID = ssid.trimmingCharacters(in: .whitespaces)
        guard !trimmedID.isEmpty, !sspassword.isEmpty else {
            throw ScraperError.missingUserCredentials
        }

        let body = try await get(
            endpoint: "ssuserInfos.php",
            extraQuery: [],
            ssid: trimmedID,
            sspassword: sspassword
        )
        let envelope = try decodeEnvelope(body)
        guard let user = envelope.response?.ssuser else {
            throw ScraperError.invalidResponse
        }
        return ScraperUserInfo(
            id:                 user.id ?? trimmedID,
            level:              user.niveau,
            contribution:       user.contribution,
            maxThreads:         Int(user.maxthreads ?? "1") ?? 1,
            maxRequestsPerDay:  Int(user.maxrequestsperday ?? "0") ?? 0,
            maxRequestsPerMin:  Int(user.maxrequestspermin ?? "0") ?? 0,
            requestsToday:      Int(user.requeststoday ?? "0") ?? 0,
            favRegion:          user.favregion,
            favLanguage:        user.favlangue
        )
    }

    /// Looks up artwork URLs for a single ROM. Does not download the images.
    /// `nameOverride` — if provided, sent to ScreenScraper as `romnom` instead
    /// of the on-disk filename. The CRC is dropped when an override is in use,
    /// because the file's CRC won't help identify a differently-named ROM.
    func lookup(romURL: URL,
                system: EmulatorSystem,
                ssid: String,
                sspassword: String,
                nameOverride: String? = nil) async throws -> ScrapedArtwork {
        guard ScreenScraperSecrets.isConfigured else { throw ScraperError.missingDevCredentials }
        guard !ssid.isEmpty, !sspassword.isEmpty else { throw ScraperError.missingUserCredentials }

        let actualName = romURL.lastPathComponent
        let lookupName = nameOverride.map { ensureZipExtension($0) } ?? actualName
        let systemID = systemeID(for: system)

        var query: [URLQueryItem] = [
            URLQueryItem(name: "systemeid", value: String(systemID)),
            URLQueryItem(name: "romnom",    value: lookupName),
        ]
        if nameOverride == nil {
            if let crc = try? crc32Hex(of: romURL) {
                query.append(URLQueryItem(name: "crc", value: crc))
            }
            if let size = try? FileManager.default.attributesOfItem(atPath: romURL.path)[.size] as? NSNumber {
                query.append(URLQueryItem(name: "romtaille", value: size.stringValue))
            }
        }

        let body = try await get(
            endpoint: "jeuInfos.php",
            extraQuery: query,
            ssid: ssid,
            sspassword: sspassword
        )
        if let envelope = try? decodeEnvelope(body),
           let jeu = envelope.response?.jeu {
            return makeArtwork(from: jeu)
        }
        // Fallback: search by stem of whichever name we used.
        let stem = (nameOverride ?? romURL.deletingPathExtension().lastPathComponent)
            .replacingOccurrences(of: ".zip", with: "")
        let searchBody = try await get(
            endpoint: "jeuRecherche.php",
            extraQuery: [
                URLQueryItem(name: "systemeid", value: String(systemID)),
                URLQueryItem(name: "recherche", value: stem),
            ],
            ssid: ssid,
            sspassword: sspassword
        )
        if let envelope = try? decodeEnvelope(searchBody),
           let first = envelope.response?.jeux?.first {
            return makeArtwork(from: first)
        }
        throw ScraperError.notFound(lookupName)
    }

    private func ensureZipExtension(_ name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        if trimmed.lowercased().hasSuffix(".zip") { return trimmed }
        if trimmed.lowercased().hasSuffix(".neo") { return trimmed }
        return trimmed + ".zip"
    }

    /// Downloads the data behind an artwork URL.
    func downloadImage(at url: URL) async throws -> Data {
        await rateLimit()
        let (data, response) = try await session.data(from: url)
        if let http = response as? HTTPURLResponse, http.statusCode != 200 {
            throw ScraperError.http(http.statusCode, "Image download failed")
        }
        return data
    }

    // MARK: System mapping

    private func systemeID(for system: EmulatorSystem) -> Int {
        switch system {
        case .neoGeoAES, .neoGeoMVS: return 142
        case .neoGeoCD:              return 70
        case .cps1:                  return 6
        case .cps2:                  return 7
        case .segaSys16, .segaSys18,
             .toaplan1, .toaplan2,
             .konamiGX, .konami68k,
             .irem, .taito:          return 75
        }
    }

    // MARK: Networking

    private func get(endpoint: String,
                     extraQuery: [URLQueryItem],
                     ssid: String,
                     sspassword: String) async throws -> Data {
        await rateLimit()

        var comps = URLComponents(url: baseURL.appendingPathComponent(endpoint),
                                  resolvingAgainstBaseURL: false)!
        var items: [URLQueryItem] = [
            URLQueryItem(name: "devid",       value: ScreenScraperSecrets.devID),
            URLQueryItem(name: "devpassword", value: ScreenScraperSecrets.devPassword),
            URLQueryItem(name: "softname",    value: ScreenScraperSecrets.softname),
            URLQueryItem(name: "output",      value: "json"),
            URLQueryItem(name: "ssid",        value: ssid),
            URLQueryItem(name: "sspassword",  value: sspassword),
        ]
        items.append(contentsOf: extraQuery)
        comps.queryItems = items
        guard let url = comps.url else { throw ScraperError.invalidResponse }

        let (data, response) = try await session.data(from: url)
        guard let http = response as? HTTPURLResponse else { throw ScraperError.invalidResponse }

        if http.statusCode == 200 { return data }

        let msg = decodeText(data)
        switch http.statusCode {
        case 401, 403: throw ScraperError.authFailed(msg)
        case 423:      throw ScraperError.apiClosed(msg)
        case 429, 430: throw ScraperError.quotaExceeded(msg)
        case 404:      throw ScraperError.notFound(msg)
        default:       throw ScraperError.http(http.statusCode, msg)
        }
    }

    private func rateLimit() async {
        let elapsed = Date().timeIntervalSince(lastRequestStartedAt)
        if elapsed < minRequestSpacing {
            let nanos = UInt64((minRequestSpacing - elapsed) * 1_000_000_000)
            try? await Task.sleep(nanoseconds: nanos)
        }
        lastRequestStartedAt = Date()
    }

    // MARK: CRC32

    private func crc32Hex(of url: URL) throws -> String {
        guard let handle = try? FileHandle(forReadingFrom: url) else {
            throw ScraperError.fileUnreadable(url)
        }
        defer { try? handle.close() }
        var crc: uLong = crc32(0, nil, 0)
        let chunkSize = 256 * 1024
        while true {
            let chunk = handle.readData(ofLength: chunkSize)
            if chunk.isEmpty { break }
            crc = chunk.withUnsafeBytes { raw -> uLong in
                guard let base = raw.baseAddress else { return crc }
                return crc32(crc,
                             base.assumingMemoryBound(to: Bytef.self),
                             uInt(raw.count))
            }
        }
        return String(format: "%08X", UInt32(crc & 0xFFFF_FFFF))
    }

    // MARK: Decoding

    private func decodeEnvelope(_ data: Data) throws -> ScraperEnvelope {
        do { return try JSONDecoder().decode(ScraperEnvelope.self, from: data) }
        catch { throw ScraperError.invalidResponse }
    }

    private func decodeText(_ data: Data) -> String {
        if let s = String(data: data, encoding: .utf8), !s.isEmpty { return s }
        return String(data: data, encoding: .isoLatin1) ?? ""
    }

    private func makeArtwork(from jeu: ScraperJeu) -> ScrapedArtwork {
        let title = (jeu.noms?.first(where: { $0.region == "wor" })?.text)
                 ?? (jeu.noms?.first(where: { $0.region == "us" })?.text)
                 ?? jeu.noms?.first?.text
                 ?? "Untitled"
        let medias = jeu.medias ?? []
        return ScrapedArtwork(
            title:          title,
            boxArtURL:      pickURL(in: medias, type: "box-2D"),
            wheelURL:       pickURL(in: medias, type: "wheel-hd") ?? pickURL(in: medias, type: "wheel"),
            marqueeURL:     pickURL(in: medias, type: "marquee"),
            boxBackURL:     pickURL(in: medias, type: "box-2D-back"),
            box3DURL:       pickURL(in: medias, type: "box-3D"),
            fanartURL:      pickURL(in: medias, type: "fanart"),
            titleScreenURL: pickURL(in: medias, type: "sstitle") ?? pickURL(in: medias, type: "title"),
            supportURL:     pickURL(in: medias, type: "support-2D"),
            bezelURL:       pickURL(in: medias, type: "bezel-16-9") ?? pickURL(in: medias, type: "bezel-4-3"),
            screenshotURLs: medias.filter { $0.type == "ss" || $0.type == "screenshot" }
                                   .compactMap { $0.url.flatMap(URL.init(string:)) }
        )
    }

    private func pickURL(in medias: [ScraperMedia], type: String) -> URL? {
        let matching = medias.filter { $0.type == type }
        let regions = ["wor", "us", "eu", "jp", "ss"]
        for region in regions {
            if let m = matching.first(where: { $0.region == region }),
               let raw = m.url, let url = URL(string: raw) {
                return url
            }
        }
        return matching.first?.url.flatMap(URL.init(string:))
    }
}

// MARK: - Wire types (subset of the ScreenScraper JSON schema)

private struct ScraperEnvelope: Decodable {
    let response: ScraperResponse?
}

private struct ScraperResponse: Decodable {
    let ssuser: ScraperSSUser?
    let jeu: ScraperJeu?
    let jeux: [ScraperJeu]?
}

private struct ScraperSSUser: Decodable {
    let id: String?
    let niveau: String?
    let contribution: String?
    let maxthreads: String?
    let maxrequestspermin: String?
    let maxrequestsperday: String?
    let requeststoday: String?
    let favregion: String?
    let favlangue: String?
}

private struct ScraperJeu: Decodable {
    let id: FlexibleString?
    let noms: [ScraperLocalisedText]?
    let medias: [ScraperMedia]?
}

private struct ScraperLocalisedText: Decodable {
    let region: String?
    let langue: String?
    let text: String?
}

private struct ScraperMedia: Decodable {
    let type: String?
    let region: String?
    let url: String?
    let format: String?
}

/// Some ScreenScraper integer fields arrive as strings, others as numbers.
private struct FlexibleString: Decodable {
    let value: String
    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if let s = try? c.decode(String.self) { value = s }
        else if let i = try? c.decode(Int.self) { value = String(i) }
        else { value = "" }
    }
}
