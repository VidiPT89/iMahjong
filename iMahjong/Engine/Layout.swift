import Foundation

/// Board layout: fixed coordinate table for the 144-tile "Turtle" spread.
/// Grid is aligned (no half-cell offset between layers) — free-tile checks
/// only ever compare integer (x, y, z), which keeps the covering/open-side
/// rules simple and unambiguous. Visual staggering between layers is done
/// purely at render time; it never touches game logic.
///
/// The base is a 9x12 grid (108 tiles) rather than the traditional 15-wide
/// turtle silhouette — same idea as Easy's reshape. What makes Medium
/// "medium" is the four-layer pyramid stacked on top (covering, not just
/// blocked-side, comes into play); the base's own width doesn't need to
/// stay wide for that, so narrowing it buys a much larger on-screen scale
/// on a portrait phone without changing the difficulty character at all.
func buildTurtleLayout() -> [BoardPosition] {
    var positions: [BoardPosition] = []
    func push(_ x: Int, _ y: Int, _ z: Int) { positions.append(BoardPosition(x: x, y: y, z: z)) }

    for y in 0..<12 {
        for x in 0..<9 { push(x, y, 0) }
    }

    // Flippers — two single-tile columns left/right at the mid rows (4)
    push(-1, 5, 0)
    push(-1, 6, 0)
    push(9, 5, 0)
    push(9, 6, 0)

    // Every upper layer is at least 2 tiles wide on every row, so a lone
    // unpairable tile can never occur at the peak (see GameEngine.computeSolvablePairing
    // for why width-1 layers are risky: a single isolated tile has no simultaneous partner).
    // Centered on the new 9x12 base (center ~x=4, y=5.5).

    // Layer 1 — 4 wide x 4 tall, centered (16)
    for y in 4...7 {
        for x in 2...5 { push(x, y, 1) }
    }

    // Layer 2 — 4 wide x 2 tall (8)
    for y in 5...6 {
        for x in 2...5 { push(x, y, 2) }
    }

    // Layer 3 — 2 wide x 2 tall (4)
    for y in 5...6 {
        for x in 3...4 { push(x, y, 3) }
    }

    // Layer 4 — the cap, 2 wide x 2 tall (4)
    for y in 5...6 {
        for x in 3...4 { push(x, y, 4) }
    }

    return positions
}

/// Easy — a 9x12 rectangular grid (108 tiles, single layer, nothing ever covered so only
/// the left/right "blocked" rule applies). Deliberately not the turtle's flat base
/// silhouette (15 columns wide, nearly twice as wide as tall) — that shape forces a much
/// smaller on-screen scale on a portrait phone. This one's proportions are close to a
/// phone's usable board area, so tiles render substantially larger.
func buildEasyLayout() -> [BoardPosition] {
    var positions: [BoardPosition] = []
    func push(_ x: Int, _ y: Int, _ z: Int) { positions.append(BoardPosition(x: x, y: y, z: z)) }

    for y in 0..<12 {
        for x in 0..<9 { push(x, y, 0) }
    }
    return positions
}

/// Hard — the same 144-tile footprint as Medium's reshaped base, but the 32 tiles above
/// the base are stacked into five progressively narrower layers instead of four, for a
/// taller peak with more covering to dig through. Every layer stays at least 2 tiles
/// wide, so the "simultaneous freeness" solvability proof in GameEngine still holds.
func buildHardLayout() -> [BoardPosition] {
    var positions: [BoardPosition] = []
    func push(_ x: Int, _ y: Int, _ z: Int) { positions.append(BoardPosition(x: x, y: y, z: z)) }

    for y in 0..<12 {
        for x in 0..<9 { push(x, y, 0) }
    }
    push(-1, 5, 0)
    push(-1, 6, 0)
    push(9, 5, 0)
    push(9, 6, 0)

    // Layer 1 — 4 wide x 4 tall, centered (16)
    for y in 4...7 { for x in 2...5 { push(x, y, 1) } }
    // Layer 2 — 4 wide x 2 tall (8)
    for y in 5...6 { for x in 2...5 { push(x, y, 2) } }
    // Layer 3 — 2 wide x 2 tall (4)
    for y in 5...6 { for x in 3...4 { push(x, y, 3) } }
    // Layer 4 — 2 wide x 1 tall (2)
    for x in 3...4 { push(x, 5, 4) }
    // Layer 5 — the cap, 2 wide x 1 tall (2)
    for x in 3...4 { push(x, 5, 5) }

    return positions
}

let TURTLE_LAYOUT = buildTurtleLayout()
let EASY_LAYOUT = buildEasyLayout()
let HARD_LAYOUT = buildHardLayout()

/// Procedural layout for the "Infinite" mode: a flat base rectangle that grows wider and
/// taller every couple of levels, with a shrinking stack of centered layers on top whose
/// count also grows with the level. Base width/height are always kept even, so every
/// layer's area stays even too, meaning the board never needs an odd tile discarded to
/// stay pairable.
///
/// Layers always shrink by 2 in each dimension and stop at 2x2 (same "never a lone
/// unpaired tile at the peak" rule as the hand-authored layouts above), so this feeds the
/// exact same computeSolvablePairingWithRetry() used everywhere else without any
/// special-casing.
func buildInfiniteLayout(_ level: Int) -> [BoardPosition] {
    var positions: [BoardPosition] = []
    func push(_ x: Int, _ y: Int, _ z: Int) { positions.append(BoardPosition(x: x, y: y, z: z)) }

    let baseW = 10 + 2 * ((level - 1) / 2)
    let baseH = 6 + 2 * ((level - 1) / 3)
    for y in 0..<baseH { for x in 0..<baseW { push(x, y, 0) } }

    let maxLayers = 1 + level / 2
    var w = baseW - 4
    var h = baseH - 2
    var z = 1
    while w >= 2 && h >= 2 && z <= maxLayers {
        let xOff = (baseW - w) / 2
        let yOff = (baseH - h) / 2
        for yy in 0..<h { for xx in 0..<w { push(xOff + xx, yOff + yy, z) } }
        w -= 2
        h -= 2
        z += 1
    }

    return positions
}

enum Difficulty: String, CaseIterable {
    case easy, medium, hard, infinite

    /// nil for `.infinite`, which has no fixed layout — its board depends on the current
    /// level (see buildInfiniteLayout), sized separately in GameEngine.
    var layout: [BoardPosition]? {
        switch self {
        case .easy: return EASY_LAYOUT
        case .medium: return TURTLE_LAYOUT
        case .hard: return HARD_LAYOUT
        case .infinite: return nil
        }
    }
}

#if DEBUG
private let _layoutCheck: Void = {
    assert(TURTLE_LAYOUT.count == 144, "Layout must have 144 tiles, has \(TURTLE_LAYOUT.count)")
    assert(EASY_LAYOUT.count == 108, "Easy layout must have 108 tiles, has \(EASY_LAYOUT.count)")
    assert(HARD_LAYOUT.count == 144, "Hard layout must have 144 tiles, has \(HARD_LAYOUT.count)")
}()
#endif
