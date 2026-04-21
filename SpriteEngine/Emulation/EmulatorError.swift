import Foundation

enum EmulatorError: LocalizedError {
    case romLoadFailed
    case biosNotFound(String)
    case unknownGame(String)
    case unsupportedFormat(String)
    case unsupportedSystem
    case saveStateFailed
    case loadStateFailed

    var errorDescription: String? {
        switch self {
        case .romLoadFailed:            return "Failed to load ROM file."
        case .biosNotFound(let name):   return "BIOS file '\(name)' not found. Please set your BIOS directory in Settings."
        case .unknownGame(let name):    return "'\(name)' is not in the game database."
        case .unsupportedFormat(let e): return ".\(e) files are not supported."
        case .unsupportedSystem:        return "This system is not supported."
        case .saveStateFailed:          return "Save state failed."
        case .loadStateFailed:          return "Load state failed."
        }
    }
}
