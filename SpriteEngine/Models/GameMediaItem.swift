import Foundation

enum GameMediaKind: String, Codable { case image, pdf }

struct GameMediaItem: Identifiable, Codable, Equatable {
    let id: UUID
    let kind: GameMediaKind
    var label: String
    let filename: String
    let addedAt: Date

    init(kind: GameMediaKind, label: String, filename: String) {
        self.id = UUID()
        self.kind = kind
        self.label = label
        self.filename = filename
        self.addedAt = Date()
    }
}
