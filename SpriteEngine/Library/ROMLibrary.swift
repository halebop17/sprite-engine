import Foundation

@MainActor
final class ROMLibrary: ObservableObject {

    static let shared = ROMLibrary()

    @Published private(set) var games: [Game] = []

    private let scanner = ROMScanner()
    private let storageURL: URL

    private init() {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = support.appendingPathComponent("SpriteEngine", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        storageURL = dir.appendingPathComponent("library.json")
        games = load()
    }

    // MARK: - Scanning

    func scan(directory: URL) async {
        let found = await scanner.scan(directory: directory)
        merge(found)
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

    // MARK: - Private

    private func merge(_ incoming: [Game]) {
        var existing = Dictionary(uniqueKeysWithValues: games.map { ($0.romURL, $0) })
        for game in incoming {
            if existing[game.romURL] == nil {
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
