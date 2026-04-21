import Foundation

struct GameMetadata: Codable {
    let romStem: String
    let title: String
    let system: EmulatorSystem
    let year: Int?
    let manufacturer: String?
    let players: Int?
}

struct ArtworkMetadata: Codable {
    let gameID: UUID
    let boxArtURL: URL?
    let screenshotURL: URL?
    let marqueeURL: URL?
}
