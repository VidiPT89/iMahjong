import Foundation

/// Winning-hand decomposition — pure functions, no UI/network dependencies, so they can
/// be exhaustively unit tested in isolation before being wired into the turn engine.

enum GroupKind { case triplet, sequence }
enum MeldKind: String { case chi, pon, kan }

struct Meld {
    var kind: MeldKind
    var tiles: [String]
    var concealed: Bool
}

struct HandGroup {
    var kind: GroupKind
    var tiles: [String]
    var meld: Meld?
}

struct Decomposition {
    var pair: String
    var groups: [HandGroup]
}

enum HandKind: Equatable { case standard, chiitoitsu, kokushi }

struct WinCheck {
    var win: Bool
    var kind: HandKind?
    var decompositions: [Decomposition]
}

func countsFromTiles(_ tiles: [String]) -> [String: Int] {
    var counts = Dictionary(uniqueKeysWithValues: STANDARD_TYPE_IDS.map { ($0, 0) })
    for t in tiles { counts[t, default: 0] += 1 }
    return counts
}

private func firstNonZero(_ counts: [String: Int]) -> String? {
    STANDARD_TYPE_IDS.first { (counts[$0] ?? 0) > 0 }
}

/// All ways to split `counts` into exactly `groupsNeeded` triplets/sequences.
func decomposeIntoGroups(_ counts: [String: Int], _ groupsNeeded: Int) -> [[HandGroup]] {
    if groupsNeeded == 0 {
        return counts.values.allSatisfy({ $0 == 0 }) ? [[]] : []
    }
    guard let type = firstNonZero(counts) else { return [] }

    var results: [[HandGroup]] = []
    let rank = rankOf(type)

    if (counts[type] ?? 0) >= 3 {
        var next = counts
        next[type]! -= 3
        for sub in decomposeIntoGroups(next, groupsNeeded - 1) {
            results.append([HandGroup(kind: .triplet, tiles: [type, type, type], meld: nil)] + sub)
        }
    }

    if let rank, rank <= 7 {
        let prefix = String(type.first!)
        let t2 = "\(prefix)\(rank + 1)"
        let t3 = "\(prefix)\(rank + 2)"
        if (counts[t2] ?? 0) > 0 && (counts[t3] ?? 0) > 0 {
            var next = counts
            next[type]! -= 1
            next[t2]! -= 1
            next[t3]! -= 1
            for sub in decomposeIntoGroups(next, groupsNeeded - 1) {
                results.append([HandGroup(kind: .sequence, tiles: [type, t2, t3], meld: nil)] + sub)
            }
        }
    }

    return results
}

/// All valid {pair, groups} decompositions of a concealed tile list into `groupsNeeded`
/// sets (3 tiles each) plus one pair. Empty array = no valid standard decomposition exists.
func findDecompositions(_ concealedTiles: [String], _ groupsNeeded: Int) -> [Decomposition] {
    let counts = countsFromTiles(concealedTiles)
    var results: [Decomposition] = []
    for type in STANDARD_TYPE_IDS {
        if (counts[type] ?? 0) >= 2 {
            var withoutPair = counts
            withoutPair[type]! -= 2
            for groups in decomposeIntoGroups(withoutPair, groupsNeeded) {
                results.append(Decomposition(pair: type, groups: groups))
            }
        }
    }
    return results
}

func isChiitoitsu(_ concealedTiles: [String]) -> Bool {
    guard concealedTiles.count == 14 else { return false }
    let counts = countsFromTiles(concealedTiles)
    let pairs = counts.values.filter { $0 == 2 }.count
    let others = counts.values.filter { $0 != 0 && $0 != 2 }.count
    return pairs == 7 && others == 0
}

let KOKUSHI_TYPES: Set<String> = ["m1", "m9", "s1", "s9", "p1", "p9", "wE", "wS", "wW", "wN", "dR", "dG", "dW"]

func isKokushiMusou(_ concealedTiles: [String]) -> Bool {
    guard concealedTiles.count == 14 else { return false }
    let counts = countsFromTiles(concealedTiles)
    var hasPair = false
    for type in STANDARD_TYPE_IDS {
        let c = counts[type] ?? 0
        if c == 0 { continue }
        if !KOKUSHI_TYPES.contains(type) { return false }
        if c >= 2 { hasPair = true }
    }
    return hasPair
}

/// Checks whether concealedTiles (length 14 - 3*melds.count) plus the fixed `melds`
/// (already-complete chi/pon/kan groups) forms a winning hand.
func checkWin(_ concealedTiles: [String], _ melds: [Meld]) -> WinCheck {
    // Meld shape kind is chi -> sequence, pon/kan -> triplet (a kan counts as a triplet
    // for shape purposes regardless of open/closed).
    let meldGroups: [HandGroup] = melds.map { m in
        HandGroup(kind: m.kind == .chi ? .sequence : .triplet, tiles: Array(m.tiles.prefix(3)), meld: m)
    }

    if melds.isEmpty {
        if isChiitoitsu(concealedTiles) { return WinCheck(win: true, kind: .chiitoitsu, decompositions: []) }
        if isKokushiMusou(concealedTiles) { return WinCheck(win: true, kind: .kokushi, decompositions: []) }
    }

    let groupsNeeded = 4 - melds.count
    let decompositions = findDecompositions(concealedTiles, groupsNeeded).map {
        Decomposition(pair: $0.pair, groups: meldGroups + $0.groups)
    }

    if !decompositions.isEmpty { return WinCheck(win: true, kind: .standard, decompositions: decompositions) }
    return WinCheck(win: false, kind: nil, decompositions: [])
}
