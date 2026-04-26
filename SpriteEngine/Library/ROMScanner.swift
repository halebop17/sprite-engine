import Foundation

final class ROMScanner {

    private let router = CoreRouter()

    /// Recursively scan `directory` for ROM files and return a `[Game]` array.
    /// Files that aren't in the GameDB are silently skipped.
    func scan(directory: URL) async -> [Game] {
        let supported: Set<String> = ["neo", "zip", "chd", "cue"]
        var games: [Game] = []

        guard let enumerator = FileManager.default.enumerator(
            at: directory,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }

        for case let fileURL as URL in enumerator {
            let ext = fileURL.pathExtension.lowercased()
            guard supported.contains(ext) else { continue }

            guard let game = makeGame(for: fileURL) else { continue }
            games.append(game)
        }

        return games.sorted { $0.title.localizedCompare($1.title) == .orderedAscending }
    }

    // MARK: - Private

    private func makeGame(for url: URL) -> Game? {
        let system: EmulatorSystem
        let ext  = url.pathExtension.lowercased()
        let stem = url.deletingPathExtension().lastPathComponent

        switch ext {
        case "neo":
            system = .neoGeoAES

        case "chd", "cue":
            system = .neoGeoCD

        case "zip":
            if let s = GameDatabase.shared[stem] {
                system = s
            } else {
                // Ask the generic FBNeo bridge — covers all compiled driver families.
                let sysCode = Int(stem.withCString { fbneo_driver_identify($0) })
                switch sysCode {
                case Int(FBNEO_SYSTEM_CPS1):      system = .cps1
                case Int(FBNEO_SYSTEM_CPS2):      system = .cps2
                case Int(FBNEO_SYSTEM_NEO_GEO):   system = .neoGeoMVS
                case Int(FBNEO_SYSTEM_SEGA_S16):  system = .segaSys16
                case Int(FBNEO_SYSTEM_SEGA_S18):  system = .segaSys18
                case Int(FBNEO_SYSTEM_TOAPLAN1):  system = .toaplan1
                case Int(FBNEO_SYSTEM_TOAPLAN2):  system = .toaplan2
                case Int(FBNEO_SYSTEM_KONAMI_GX): system = .konamiGX
                case Int(FBNEO_SYSTEM_KONAMI_68K):system = .konami68k
                case Int(FBNEO_SYSTEM_IREM):      system = .irem
                case Int(FBNEO_SYSTEM_TAITO):     system = .taito
                default: return nil
                }
            }

        default:
            return nil
        }

        let title = titleFor(stem: stem, system: system)

        return Game(
            id:         UUID(),
            title:      title,
            system:     system,
            romURL:     url,
            artworkURL: nil,
            lastPlayed: nil,
            isFavorite: false,
            saveStates: []
        )
    }

    /// Produce a human-readable title from the zip stem.
    /// Strips trailing region codes (u/j/a/b/e/r/w) and capitalises words.
    private func titleFor(stem: String, system: EmulatorSystem) -> String {
        // Strip common numeric or single-char region suffixes (e.g. "sf2u" → "sf2")
        var base = stem
        let regionSuffixes = ["u", "j", "a", "b", "e", "r", "w", "h", "ch", "j1", "j2"]
        for suffix in regionSuffixes {
            if base.lowercased().hasSuffix(suffix) && base.count > suffix.count + 1 {
                base = String(base.dropLast(suffix.count))
                break
            }
        }
        // Insert spaces before digits that follow letters (e.g. "sf2" → "sf 2")
        var spaced = ""
        for (i, ch) in base.enumerated() {
            if i > 0 && ch.isNumber && base[base.index(base.startIndex, offsetBy: i - 1)].isLetter {
                spaced.append(" ")
            }
            spaced.append(ch)
        }
        return spaced.uppercased()
    }
}
