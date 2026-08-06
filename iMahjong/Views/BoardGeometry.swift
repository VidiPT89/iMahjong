import SwiftUI

/// Extents depend on which difficulty's layout is active (Easy drops the flippers and
/// every upper layer; Hard adds a 5th one) — computed from the engine's own tiles rather
/// than a single fixed layout, so board sizing and tile placement stay correct no matter
/// which one is in play.
struct BoardExtents {
    let minX: Int
    let maxX: Int
    let minY: Int
    let maxY: Int
    let maxZ: Int

    init(tiles: [GameTile]) {
        minX = tiles.map { $0.x }.min() ?? 0
        maxX = tiles.map { $0.x }.max() ?? 0
        minY = tiles.map { $0.y }.min() ?? 0
        maxY = tiles.map { $0.y }.max() ?? 0
        maxZ = tiles.map { $0.z }.max() ?? 0
    }
}

enum BoardGeometry {
    static let tileW: CGFloat = 44
    static let tileH: CGFloat = 60
    static let stepX: CGFloat = tileW * 0.86
    static let stepY: CGFloat = tileH * 0.82
    static let layerNudge: CGFloat = 5

    static func boardWidth(_ extents: BoardExtents) -> CGFloat {
        let maxLayer = CGFloat(extents.maxZ)
        return (CGFloat(extents.maxX - extents.minX) + 1) * stepX + tileW + maxLayer * layerNudge * 2
    }

    static func boardHeight(_ extents: BoardExtents) -> CGFloat {
        let maxLayer = CGFloat(extents.maxZ)
        return (CGFloat(extents.maxY - extents.minY) + 1) * stepY + tileH + maxLayer * layerNudge * 2
    }

    static func point(for tile: GameTile, in extents: BoardExtents) -> CGPoint {
        let maxLayer = CGFloat(extents.maxZ)
        let nudge = CGFloat(tile.z) * layerNudge
        let x = CGFloat(tile.x - extents.minX) * stepX + tileW / 2 + (maxLayer * layerNudge - nudge)
        let y = CGFloat(tile.y - extents.minY) * stepY + tileH / 2 + (maxLayer * layerNudge - nudge)
        return CGPoint(x: x, y: y)
    }

    static func zIndex(for tile: GameTile) -> Double {
        Double(tile.z * 1000 + tile.y * 20 + tile.x + 50)
    }
}
