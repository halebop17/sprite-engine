import Foundation

struct Game: Identifiable, Codable {
    let id: UUID
    let title: String
    let system: EmulatorSystem
    let romURL: URL
    let artworkURL: URL?
    var lastPlayed: Date?
    var isFavorite: Bool
    var saveStates: [SaveState]
}
