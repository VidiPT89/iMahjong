import SwiftUI

enum BoardGeometry {
    static let tileW: CGFloat = 44
    static let tileH: CGFloat = 60
    static let stepX: CGFloat = tileW * 0.86
    static let stepY: CGFloat = tileH * 0.82
    static let layerNudge: CGFloat = 5
    static let maxLayer: CGFloat = 4

    static let minX = TURTLE_LAYOUT.map { $0.x }.min()!
    static let maxX = TURTLE_LAYOUT.map { $0.x }.max()!
    static let minY = TURTLE_LAYOUT.map { $0.y }.min()!
    static let maxY = TURTLE_LAYOUT.map { $0.y }.max()!

    static var boardWidth: CGFloat {
        (CGFloat(maxX - minX) + 1) * stepX + tileW + maxLayer * layerNudge * 2
    }

    static var boardHeight: CGFloat {
        (CGFloat(maxY - minY) + 1) * stepY + tileH + maxLayer * layerNudge * 2
    }

    static func point(for tile: GameTile) -> CGPoint {
        let nudge = CGFloat(tile.z) * layerNudge
        let x = CGFloat(tile.x - minX) * stepX + tileW / 2 + (maxLayer * layerNudge - nudge)
        let y = CGFloat(tile.y - minY) * stepY + tileH / 2 + (maxLayer * layerNudge - nudge)
        return CGPoint(x: x, y: y)
    }

    static func zIndex(for tile: GameTile) -> Double {
        Double(tile.z * 1000 + tile.y * 20 + tile.x + 50)
    }
}
