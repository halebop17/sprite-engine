import Foundation

// MARK: - Models

enum ROMFileStatus: Equatable {
    case ok
    case missing
    case wrongCRC(expected: UInt32, actual: UInt32)
    case optional

    var isOK: Bool {
        if case .ok = self { return true }
        if case .optional = self { return true }
        return false
    }

    var label: String {
        switch self {
        case .ok:                           return "OK"
        case .missing:                      return "Missing"
        case .wrongCRC(let e, let a):       return "Wrong CRC (expected \(String(e, radix: 16)), got \(String(a, radix: 16)))"
        case .optional:                     return "Optional"
        }
    }
}

struct ROMFileResult: Identifiable {
    let id = UUID()
    let name: String
    let status: ROMFileStatus
}

enum GameVerificationStatus: Equatable {
    case ok
    case issues(missing: Int, wrongCRC: Int)
    case unknownGame

    var isOK: Bool {
        if case .ok = self { return true }
        return false
    }

    var label: String {
        switch self {
        case .ok:                           return "OK"
        case .issues(let m, let c):
            var parts: [String] = []
            if m > 0 { parts.append("\(m) missing") }
            if c > 0 { parts.append("\(c) wrong CRC") }
            return parts.joined(separator: ", ")
        case .unknownGame:                  return "Unknown game"
        }
    }
}

struct GameVerificationResult: Identifiable {
    let id = UUID()
    let game: Game
    let status: GameVerificationStatus
    let files: [ROMFileResult]
}

// MARK: - Verifier

final class ROMVerifier {

    static let shared = ROMVerifier()
    private init() {}

    // Maximum ROM slots we read per game (generous upper bound).
    private static let maxSlots = 256

    /// Verify all FBNeo games (CPS, Sega, Toaplan, Konami GX, …) in the library.
    /// Runs on a background thread; progress is reported via `onProgress`.
    func verify(
        games: [Game],
        onProgress: @escaping (Int, Int) -> Void,
        completion: @escaping ([GameVerificationResult]) -> Void
    ) {
        let fbGames = games.filter {
            $0.system.coreType == .fbneopCPS || $0.system.coreType == .fbneo
        }
        DispatchQueue.global(qos: .userInitiated).async {
            var results: [GameVerificationResult] = []
            for (idx, game) in fbGames.enumerated() {
                DispatchQueue.main.async { onProgress(idx, fbGames.count) }
                let result = self.verifyGame(game)
                results.append(result)
            }
            DispatchQueue.main.async { completion(results) }
        }
    }

    private func verifyGame(_ game: Game) -> GameVerificationResult {
        let path = game.romURL.path

        var rawFiles = [FBNeoRomFile](repeating: FBNeoRomFile(), count: Self.maxSlots)
        let total = rawFiles.withUnsafeMutableBufferPointer { buf -> Int32 in
            if game.system.coreType == .fbneopCPS {
                return fbneo_cps_verify_game(path, buf.baseAddress, Int32(Self.maxSlots))
            } else {
                return fbneo_driver_verify_game(path, buf.baseAddress, Int32(Self.maxSlots))
            }
        }

        guard total >= 0 else {
            return GameVerificationResult(game: game, status: .unknownGame, files: [])
        }

        var fileResults: [ROMFileResult] = []
        var missingCount = 0
        var wrongCRCCount = 0

        let count = min(Int(total), Self.maxSlots)
        for i in 0..<count {
            let raw = rawFiles[i]
            let name = withUnsafeBytes(of: raw.name) { ptr -> String in
                String(cString: ptr.bindMemory(to: CChar.self).baseAddress!)
            }
            let status: ROMFileStatus
            switch raw.status {
            case FBNEO_ROM_OK:       status = .ok
            case FBNEO_ROM_MISSING:  status = .missing;  missingCount += 1
            case FBNEO_ROM_WRONG_CRC:
                status = .wrongCRC(expected: raw.expectedCrc, actual: raw.actualCrc)
                wrongCRCCount += 1
            default:                 status = .optional
            }
            fileResults.append(ROMFileResult(name: name, status: status))
        }

        let gameStatus: GameVerificationStatus = (missingCount == 0 && wrongCRCCount == 0)
            ? .ok
            : .issues(missing: missingCount, wrongCRC: wrongCRCCount)

        return GameVerificationResult(game: game, status: gameStatus, files: fileResults)
    }
}
