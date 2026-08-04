import Foundation

/// Board layout: fixed coordinate table for the 144-tile "Turtle" spread.
/// Grid is aligned (no half-cell offset between layers) — free-tile checks
/// only ever compare integer (x, y, z), which keeps the covering/open-side
/// rules simple and unambiguous. Visual staggering between layers is done
/// purely at render time; it never touches game logic.
func buildTurtleLayout() -> [BoardPosition] {
    var positions: [BoardPosition] = []
    func push(_ x: Int, _ y: Int, _ z: Int) { positions.append(BoardPosition(x: x, y: y, z: z)) }

    // Layer 0 — base silhouette (widths: 11,13,15,15,15,15,13,11 = 108)
    let baseRows: [(y: Int, x0: Int, x1: Int)] = [
        (0, 2, 12), (1, 1, 13), (2, 0, 14), (3, 0, 14),
        (4, 0, 14), (5, 0, 14), (6, 1, 13), (7, 2, 12),
    ]
    for row in baseRows {
        for x in row.x0...row.x1 { push(x, row.y, 0) }
    }

    // Flippers — two single-tile columns left/right at the mid rows (4)
    push(-1, 3, 0)
    push(-1, 4, 0)
    push(15, 3, 0)
    push(15, 4, 0)

    // Every upper layer is at least 2 tiles wide on every row, so a lone
    // unpairable tile can never occur at the peak (see GameEngine.computeSolvablePairing
    // for why width-1 layers are risky: a single isolated tile has no simultaneous partner).

    // Layer 1 — 4 wide x 4 tall, centered (16)
    for y in 2...5 {
        for x in 6...9 { push(x, y, 1) }
    }

    // Layer 2 — 4 wide x 2 tall (8)
    for y in 3...4 {
        for x in 6...9 { push(x, y, 2) }
    }

    // Layer 3 — 2 wide x 2 tall (4)
    for y in 3...4 {
        for x in 7...8 { push(x, y, 3) }
    }

    // Layer 4 — the cap, 2 wide x 2 tall (4)
    for y in 3...4 {
        for x in 7...8 { push(x, y, 4) }
    }

    return positions
}

let TURTLE_LAYOUT = buildTurtleLayout()

#if DEBUG
private let _layoutCheck: Void = {
    assert(TURTLE_LAYOUT.count == 144, "Layout must have 144 tiles, has \(TURTLE_LAYOUT.count)")
}()
#endif
