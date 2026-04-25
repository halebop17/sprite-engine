import Foundation

final class GameDatabase {
    static let shared = GameDatabase()

    private let db: [String: EmulatorSystem]

    private init() {
        guard
            let url  = Bundle.main.url(forResource: "GameDB", withExtension: "json"),
            let data = try? Data(contentsOf: url),
            let raw  = try? JSONDecoder().decode([String: String].self, from: data)
        else {
            db = [:]
            return
        }

        var built: [String: EmulatorSystem] = [:]
        for (key, value) in raw {
            switch value {
            case "cps1":       built[key] = .cps1
            case "cps2":       built[key] = .cps2
            case "neoGeoMVS":  built[key] = .neoGeoMVS
            case "neoGeoAES":  built[key] = .neoGeoAES
            case "neoGeoCD":   built[key] = .neoGeoCD
            case "segaSys16":  built[key] = .segaSys16
            case "segaSys18":  built[key] = .segaSys18
            case "toaplan1":   built[key] = .toaplan1
            case "toaplan2":   built[key] = .toaplan2
            case "konamiGX":   built[key] = .konamiGX
            case "irem":       built[key] = .irem
            case "taito":      built[key] = .taito
            default: break
            }
        }
        db = built
    }

    /// Look up the EmulatorSystem for a ROM zip stem (e.g. "sf2", "mslug").
    subscript(name: String) -> EmulatorSystem? { db[name.lowercased()] }

    /// Returns true if the zip stem is a known Neo Geo MVS title.
    func isNeoGeoMVS(_ name: String) -> Bool { db[name.lowercased()] == .neoGeoMVS }
}
