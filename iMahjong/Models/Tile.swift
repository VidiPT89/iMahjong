import Foundation

struct BoardPosition {
    let x: Int
    let y: Int
    let z: Int
}

struct GameTile: Identifiable, Equatable, Codable {
    let id: Int
    let x: Int
    let y: Int
    let z: Int
    var removed: Bool
    var typeId: String?
}
