import Foundation

struct SaveState: Identifiable, Codable, Equatable {
    let id: UUID
    let gameName: String
    let system: EmulatorSystem
    let createdAt: Date
    let dataURL: URL
    let thumbnailURL: URL
}
