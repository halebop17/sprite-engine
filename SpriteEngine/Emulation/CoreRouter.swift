import Foundation

final class CoreRouter {

    private let db = GameDatabase.shared

    /// Create the correct EmulatorCore for the given ROM URL.
    ///
    /// Routing rules:
    ///   .neo            → GeolithCore(.neoGeoAES)
    ///   .chd / .cue     → GeolithCore(.neoGeoCD)
    ///   .zip            → look up stem in GameDB
    ///     cps1/cps2     → FBNeoCPSCore
    ///     neoGeoMVS     → GeolithCore(.neoGeoMVS)
    ///     neoGeoAES     → GeolithCore(.neoGeoAES)
    ///     not found     → throws unknownGame
    ///   anything else   → throws unsupportedFormat
    func core(for url: URL) throws -> any EmulatorCore {
        switch url.pathExtension.lowercased() {

        case "neo":
            return GeolithCore(system: .neoGeoAES)

        case "chd", "cue":
            return GeolithCore(system: .neoGeoCD)

        case "zip":
            let stem = url.deletingPathExtension().lastPathComponent.lowercased()
            guard let system = db[stem] else {
                throw EmulatorError.unknownGame(stem)
            }
            switch system {
            case .cps1:      return FBNeoCPSCore(system: .cps1)
            case .cps2:      return FBNeoCPSCore(system: .cps2)
            case .neoGeoMVS: return GeolithCore(system: .neoGeoMVS)
            case .neoGeoAES: return GeolithCore(system: .neoGeoAES)
            case .neoGeoCD:  return GeolithCore(system: .neoGeoCD)
            }

        default:
            throw EmulatorError.unsupportedFormat(url.pathExtension)
        }
    }
}
