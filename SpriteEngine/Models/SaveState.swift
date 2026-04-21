import Foundation

struct SaveState: Codable {
    let id: UUID
    let gameName: String
    let system: EmulatorSystem
    let createdAt: Date
    let dataURL: URL
    let thumbnailURL: URL
}
