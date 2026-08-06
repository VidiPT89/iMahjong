import Foundation

enum TileCategory {
    case suit, wind, dragon, flower, season
}

enum Suit {
    case characters, bamboo, circle
}

struct TileType: Identifiable {
    let id: String
    let category: TileCategory
    let suit: Suit?
    let rank: Int?
    let count: Int
}

/// Dot / bamboo pip grid layouts per rank, shared between circle and bamboo suits.
let pipRows: [Int: [Int]] = [
    1: [1], 2: [1, 1], 3: [1, 1, 1], 4: [2, 2], 5: [2, 1, 2],
    6: [2, 2, 2], 7: [2, 2, 2, 1], 8: [2, 2, 2, 2], 9: [3, 3, 3],
]

let numerals = ["", "一", "二", "三", "四", "五", "六", "七", "八", "九"]

/// Builds the flat list of 34 tile "types" used across the game (144 instances total).
/// Standard Mahjong notation (m=man/characters, s=sou/bamboo, p=pin/circle) — using the
/// suit's first letter would collide, since "characters" and "circle" both start with "c".
func buildTileTypes() -> [TileType] {
    var types: [TileType] = []

    let suits: [(Suit, String)] = [(.characters, "m"), (.bamboo, "s"), (.circle, "p")]
    for (suit, prefix) in suits {
        for rank in 1...9 {
            types.append(TileType(id: "\(prefix)\(rank)", category: .suit, suit: suit, rank: rank, count: 4))
        }
    }

    let winds = ["E", "S", "W", "N"]
    for code in winds {
        types.append(TileType(id: "w\(code)", category: .wind, suit: nil, rank: nil, count: 4))
    }

    types.append(TileType(id: "dR", category: .dragon, suit: nil, rank: nil, count: 4))
    types.append(TileType(id: "dG", category: .dragon, suit: nil, rank: nil, count: 4))
    types.append(TileType(id: "dW", category: .dragon, suit: nil, rank: nil, count: 4))

    for i in 1...4 {
        types.append(TileType(id: "fl\(i)", category: .flower, suit: nil, rank: i, count: 1))
    }
    for i in 1...4 {
        types.append(TileType(id: "se\(i)", category: .season, suit: nil, rank: i, count: 1))
    }

    return types
}

let TILE_TYPES = buildTileTypes()
let TILE_TYPES_BY_ID: [String: TileType] = Dictionary(uniqueKeysWithValues: TILE_TYPES.map { ($0.id, $0) })

/// Two tile instances match if they can legally form a pair.
func tilesMatch(_ typeIdA: String, _ typeIdB: String) -> Bool {
    guard let a = TILE_TYPES_BY_ID[typeIdA], let b = TILE_TYPES_BY_ID[typeIdB] else { return false }
    if typeIdA == typeIdB {
        return a.category != .flower && a.category != .season
    }
    if a.category == .flower && b.category == .flower { return true }
    if a.category == .season && b.category == .season { return true }
    return false
}

/// Builds 72 shuffled "pair units" (each a matching [typeA, typeB]) covering all 144
/// tiles. Consumed by the engine, which assigns each unit to a pair of board positions
/// guaranteed to be simultaneously free at some point during a full solve.
func buildShuffledPairUnits() -> [(String, String)] {
    var units: [(String, String)] = []
    for t in TILE_TYPES where t.category != .flower && t.category != .season {
        units.append((t.id, t.id))
        units.append((t.id, t.id))
    }

    var flowerIds = TILE_TYPES.filter { $0.category == .flower }.map { $0.id }
    var seasonIds = TILE_TYPES.filter { $0.category == .season }.map { $0.id }
    flowerIds.shuffle()
    seasonIds.shuffle()
    units.append((flowerIds[0], flowerIds[1]))
    units.append((flowerIds[2], flowerIds[3]))
    units.append((seasonIds[0], seasonIds[1]))
    units.append((seasonIds[2], seasonIds[3]))

    units.shuffle()
    return units.map { Bool.random() ? ($0.1, $0.0) : $0 }
}

/// Easy mode's pool: numbered suit tiles only (27 types x4 = 108), no
/// winds/dragons/bonus tiles to memorize the positions of.
func buildEasyPairUnits() -> [(String, String)] {
    var units: [(String, String)] = []
    for t in TILE_TYPES where t.category == .suit {
        units.append((t.id, t.id))
        units.append((t.id, t.id))
    }
    units.shuffle()
    return units.map { Bool.random() ? ($0.1, $0.0) : $0 }
}

/// Picks the right pair-unit pool for a fresh deal at the given difficulty.
func buildPairUnits(for difficulty: Difficulty) -> [(String, String)] {
    difficulty == .easy ? buildEasyPairUnits() : buildShuffledPairUnits()
}

/// Builds matching pair-units from whatever type inventory is passed in (e.g. the types
/// still on the board when reshuffling mid-game).
func buildPairUnitsFromInventory(_ typeCounts: [String: Int]) -> [(String, String)] {
    var units: [(String, String)] = []
    var bonus: [TileCategory: [String]] = [.flower: [], .season: []]

    for (id, count) in typeCounts {
        guard let t = TILE_TYPES_BY_ID[id] else { continue }
        if t.category == .flower || t.category == .season {
            for _ in 0..<count { bonus[t.category, default: []].append(id) }
        } else {
            var n = count
            while n >= 2 { units.append((id, id)); n -= 2 }
        }
    }

    for cat in [TileCategory.flower, .season] {
        bonus[cat]?.shuffle()
        while (bonus[cat]?.count ?? 0) >= 2 {
            let a = bonus[cat]!.removeLast()
            let b = bonus[cat]!.removeLast()
            units.append((a, b))
        }
    }

    units.shuffle()
    return units.map { Bool.random() ? ($0.1, $0.0) : $0 }
}
