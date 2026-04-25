import Foundation

enum CoreType {
    case geolith
    case fbneopCPS
    case fbneo
}

enum EmulatorSystem: String, Codable, CaseIterable {
    case neoGeoAES  = "Neo Geo AES"
    case neoGeoMVS  = "Neo Geo MVS"
    case neoGeoCD   = "Neo Geo CD"
    case cps1       = "CPS-1"
    case cps2       = "CPS-2"
    case segaSys16  = "Sega System 16"
    case segaSys18  = "Sega System 18"
    case toaplan1   = "Toaplan 1"
    case toaplan2   = "Toaplan 2"
    case konamiGX   = "Konami GX"
    case irem       = "Irem"
    case taito      = "Taito"

    var coreType: CoreType {
        switch self {
        case .neoGeoAES, .neoGeoMVS, .neoGeoCD:
            return .geolith
        case .cps1, .cps2:
            return .fbneopCPS
        case .segaSys16, .segaSys18, .toaplan1, .toaplan2, .konamiGX, .irem, .taito:
            return .fbneo
        }
    }

    /// Human-readable platform name shown in the UI.
    var displayName: String { rawValue }
}
