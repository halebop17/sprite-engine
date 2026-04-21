import Foundation

enum CoreType {
    case geolith
    case fbneopCPS
}

enum EmulatorSystem: String, Codable, CaseIterable {
    case neoGeoAES = "Neo Geo AES"
    case neoGeoMVS = "Neo Geo MVS"
    case neoGeoCD  = "Neo Geo CD"
    case cps1      = "CPS-1"
    case cps2      = "CPS-2"

    var coreType: CoreType {
        switch self {
        case .neoGeoAES, .neoGeoMVS, .neoGeoCD: return .geolith
        case .cps1, .cps2:                       return .fbneopCPS
        }
    }
}
