import Foundation

@MainActor
final class ROMLibrary: ObservableObject {

    static let shared = ROMLibrary()

    @Published private(set) var games: [Game] = []
    @Published private(set) var verificationResults: [UUID: GameVerificationResult] = [:]

    private let scanner = ROMScanner()
    private let storageURL: URL

    private init() {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = support.appendingPathComponent("SpriteEngine", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        storageURL = dir.appendingPathComponent("library.json")
        games = load()
        refreshTitlesFromBridge()
    }

    /// Ask the FBNeo bridge for the canonical full name of every .zip game and
    /// update any titles that have changed. Cheap (metadata only — no ROM I/O)
    /// and keeps existing libraries in sync as the bridge gains new drivers.
    private func refreshTitlesFromBridge() {
        var changed = false
        for i in games.indices {
            let url = games[i].romURL
            guard url.pathExtension.lowercased() == "zip" else { continue }
            let stem = url.deletingPathExtension().lastPathComponent
            var buf = [CChar](repeating: 0, count: 256)
            let ok = stem.withCString { c -> Int32 in
                buf.withUnsafeMutableBufferPointer { bp in
                    fbneo_driver_full_name(c, bp.baseAddress, bp.count)
                }
            }
            guard ok == 1 else { continue }
            let real = String(cString: buf)
            guard !real.isEmpty, real != games[i].title else { continue }
            games[i] = Game(
                id:         games[i].id,
                title:      real,
                system:     games[i].system,
                romURL:     games[i].romURL,
                artworkURL: games[i].artworkURL,
                lastPlayed: games[i].lastPlayed,
                isFavorite: games[i].isFavorite,
                saveStates: games[i].saveStates
            )
            changed = true
        }
        if changed {
            games.sort { $0.title.localizedCompare($1.title) == .orderedAscending }
            save()
        }
    }

    // MARK: - Scanning

    func scan(directory: URL) async {
        let found = await scanner.scan(directory: directory)
        merge(found)
        save()
    }

    func scan(directories: [URL]) async {
        var all: [Game] = []
        for dir in directories {
            let found = await scanner.scan(directory: dir)
            all.append(contentsOf: found)
        }
        merge(all)
        save()
    }

    // MARK: - Mutation

    func setFavorite(_ game: Game, _ value: Bool) {
        update(game.id) { $0.isFavorite = value }
    }

    func recordPlayed(_ game: Game) {
        update(game.id) { $0.lastPlayed = Date() }
    }

    func remove(_ game: Game) {
        games.removeAll { $0.id == game.id }
        save()
    }

    func updateVerificationResults(_ results: [GameVerificationResult]) {
        verificationResults = Dictionary(uniqueKeysWithValues: results.map { ($0.game.id, $0) })
    }

    func removeGames(inDirectory directory: URL) {
        let prefix = directory.standardizedFileURL.path
        games.removeAll { $0.romURL.standardizedFileURL.path.hasPrefix(prefix) }
        save()
    }

    func pruneToDirectories(_ directories: [URL]) {
        guard !directories.isEmpty else { return }
        // Normalise each directory to "…/path/" (trailing slash) so that
        // hasPrefix() never matches a directory that is merely a prefix of
        // another name (e.g. "/ROMs" should not match "/ROMs2/game.zip").
        let prefixes = directories.map { url -> String in
            var p = url.standardizedFileURL.path
            if !p.hasSuffix("/") { p += "/" }
            return p
        }
        let before = games.count
        games.removeAll { game in
            var path = game.romURL.standardizedFileURL.path
            if !path.hasSuffix("/") { path += "/" }
            return !prefixes.contains { path.hasPrefix($0) }
        }
        if games.count != before { save() }
    }

    func addSaveState(_ state: SaveState, to game: Game) {
        update(game.id) { $0.saveStates.append(state) }
    }

    func removeSaveState(_ state: SaveState, from game: Game) {
        SaveStateManager.delete(state)
        update(game.id) { $0.saveStates.removeAll { $0.id == state.id } }
    }

    // MARK: - Private

    private func merge(_ incoming: [Game]) {
        var existing = Dictionary(uniqueKeysWithValues: games.map { ($0.romURL, $0) })
        for game in incoming {
            if var prev = existing[game.romURL] {
                // Refresh metadata from a rescan (title, system, artwork) while
                // preserving the persistent id and user-state fields.
                prev = Game(
                    id:         prev.id,
                    title:      game.title,
                    system:     game.system,
                    romURL:     prev.romURL,
                    artworkURL: game.artworkURL ?? prev.artworkURL,
                    lastPlayed: prev.lastPlayed,
                    isFavorite: prev.isFavorite,
                    saveStates: prev.saveStates
                )
                existing[game.romURL] = prev
            } else {
                existing[game.romURL] = game
            }
        }
        // Remove entries whose ROM files no longer exist on disk
        existing = existing.filter { FileManager.default.fileExists(atPath: $0.key.path) }
        games = existing.values.sorted { $0.title.localizedCompare($1.title) == .orderedAscending }
    }

    private func update(_ id: UUID, _ mutation: (inout Game) -> Void) {
        guard let idx = games.firstIndex(where: { $0.id == id }) else { return }
        mutation(&games[idx])
        save()
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(games) else { return }
        try? data.write(to: storageURL, options: .atomic)
    }

    private func load() -> [Game] {
        guard
            let data = try? Data(contentsOf: storageURL),
            let decoded = try? JSONDecoder().decode([Game].self, from: data)
        else { return [] }
        return decoded.filter { FileManager.default.fileExists(atPath: $0.romURL.path) }
    }
}
