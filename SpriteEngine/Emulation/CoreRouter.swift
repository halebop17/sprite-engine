import Foundation

final class CoreRouter {

    private let db = GameDatabase.shared

    /// Create the correct EmulatorCore for the given ROM URL.
    func core(for url: URL) throws -> any EmulatorCore {
        switch url.pathExtension.lowercased() {

        case "neo":
            return GeolithCore(system: .neoGeoAES)

        case "chd", "cue":
            return GeolithCore(system: .neoGeoCD)

        case "zip":
            let stem = url.deletingPathExtension().lastPathComponent.lowercased()

            // Static DB lookup first.
            if let system = db[stem] {
                return makeCore(for: system)
            }

            // Fall back to live FBNeo driver list.
            // Ask the generic bridge — it covers all compiled driver families.
            let sysCode = stem.withCString { fbneo_driver_identify($0) }
            switch Int(sysCode) {
            case Int(FBNEO_SYSTEM_CPS1):      return FBNeoCPSCore(system: .cps1)
            case Int(FBNEO_SYSTEM_CPS2):      return FBNeoCPSCore(system: .cps2)
            case Int(FBNEO_SYSTEM_NEO_GEO):   return GeolithCore(system: .neoGeoMVS)
            case Int(FBNEO_SYSTEM_SEGA_S16):  return FBNeoCore(system: .segaSys16)
            case Int(FBNEO_SYSTEM_SEGA_S18):  return FBNeoCore(system: .segaSys18)
            case Int(FBNEO_SYSTEM_TOAPLAN1):  return FBNeoCore(system: .toaplan1)
            case Int(FBNEO_SYSTEM_TOAPLAN2):  return FBNeoCore(system: .toaplan2)
            case Int(FBNEO_SYSTEM_KONAMI_GX): return FBNeoCore(system: .konamiGX)
            case Int(FBNEO_SYSTEM_IREM):      return FBNeoCore(system: .irem)
            case Int(FBNEO_SYSTEM_TAITO):     return FBNeoCore(system: .taito)
            default: throw EmulatorError.unknownGame(stem)
            }

        default:
            throw EmulatorError.unsupportedFormat(url.pathExtension)
        }
    }

    private func makeCore(for system: EmulatorSystem) -> any EmulatorCore {
        switch system {
        case .cps1:      return FBNeoCPSCore(system: .cps1)
        case .cps2:      return FBNeoCPSCore(system: .cps2)
        case .neoGeoAES: return GeolithCore(system: .neoGeoAES)
        case .neoGeoMVS: return GeolithCore(system: .neoGeoMVS)
        case .neoGeoCD:  return GeolithCore(system: .neoGeoCD)
        case .segaSys16: return FBNeoCore(system: .segaSys16)
        case .segaSys18: return FBNeoCore(system: .segaSys18)
        case .toaplan1:  return FBNeoCore(system: .toaplan1)
        case .toaplan2:  return FBNeoCore(system: .toaplan2)
        case .konamiGX:  return FBNeoCore(system: .konamiGX)
        case .irem:      return FBNeoCore(system: .irem)
        case .taito:     return FBNeoCore(system: .taito)
        }
    }
}
