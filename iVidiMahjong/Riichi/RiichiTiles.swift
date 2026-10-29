import Foundation

/// Standard 136-tile Riichi set — reuses the 34 "standard" tile types (suits, winds,
/// dragons) already defined for Solitaire, so tile faces stay pixel-identical between
/// modes. Flowers/Seasons are intentionally excluded (not part of the base 136-tile wall).
let STANDARD_TYPE_IDS: [String] = TILE_TYPES
    .filter { $0.category == .suit || $0.category == .wind || $0.category == .dragon }
    .map { $0.id }

/// Opaque "suit" grouping key — for suit tiles this is the actual suit; for honors it's
/// a stand-in ("wind"/"dragon") used only for equality comparisons (e.g. iipeiko keys).
let SUIT_OF: [String: String] = Dictionary(uniqueKeysWithValues: STANDARD_TYPE_IDS.map { id in
    let t = TILE_TYPES_BY_ID[id]!
    if t.category == .suit {
        switch t.suit! {
        case .characters: return (id, "characters")
        case .bamboo: return (id, "bamboo")
        case .circle: return (id, "circle")
        }
    }
    return (id, t.category == .wind ? "wind" : "dragon")
})

let RANK_OF: [String: Int?] = Dictionary(uniqueKeysWithValues: STANDARD_TYPE_IDS.map { id in
    (id, TILE_TYPES_BY_ID[id]!.rank)
})

func rankOf(_ id: String) -> Int? { RANK_OF[id] ?? nil }

func isHonor(_ typeId: String) -> Bool {
    let cat = TILE_TYPES_BY_ID[typeId]!.category
    return cat == .wind || cat == .dragon
}
func isTerminal(_ typeId: String) -> Bool {
    let t = TILE_TYPES_BY_ID[typeId]!
    return t.category == .suit && (t.rank == 1 || t.rank == 9)
}
func isTerminalOrHonor(_ typeId: String) -> Bool {
    isHonor(typeId) || isTerminal(typeId)
}

struct RiichiTile {
    let id: Int
    let typeId: String
}

/// Builds one shuffled 136-tile wall.
func buildWall() -> [RiichiTile] {
    var tiles: [RiichiTile] = []
    var uid = 0
    for typeId in STANDARD_TYPE_IDS {
        for _ in 0..<4 {
            tiles.append(RiichiTile(id: uid, typeId: typeId))
            uid += 1
        }
    }
    tiles.shuffle()
    return tiles
}

struct DealtWall {
    var liveWall: [RiichiTile]
    var deadWall: [RiichiTile]
    var hands: [[RiichiTile]]
}

/// Deals a fresh hand: 13 tiles to each of 4 seats (E/S/W/N), a 14-tile dead wall (dora
/// indicator = its first tile), and the remaining live wall to draw from. Seat 0 is
/// always the dealer (East).
func dealWall() -> DealtWall {
    var wall = buildWall()
    var hands: [[RiichiTile]] = [[], [], [], []]
    for _ in 0..<13 {
        for seat in 0..<4 {
            hands[seat].append(wall.removeLast())
        }
    }
    var deadWall: [RiichiTile] = []
    for _ in 0..<14 {
        deadWall.append(wall.removeLast())
    }
    return DealtWall(liveWall: wall, deadWall: deadWall, hands: hands)
}
