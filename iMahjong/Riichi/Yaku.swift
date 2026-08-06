import Foundation

/// Yaku (winning-hand pattern) detection and fu calculation for Riichi scoring.
/// Evaluated per-decomposition — the turn engine tries every decomposition of a winning
/// hand and keeps the highest score.
///
/// Scope note: covers the common competitive yaku set plus all yakuman. Intentionally
/// simplifies a few rare edge cases (e.g. double-yakuman variants count as a single
/// yakuman here) rather than chasing every tournament-rule nuance.

let GREEN_TILES: Set<String> = ["s2", "s3", "s4", "s6", "s8", "dG"]

enum WinType { case ron, tsumo }

struct WinContext {
    var concealed: Bool
    var openMelds: [Meld]
    var winTile: String
    var winType: WinType
    var seatWind: String
    var roundWind: String
    var riichi: Bool
    var doubleRiichi: Bool
    var ippatsu: Bool
    var haitei: Bool
    var houtei: Bool
    var rinshan: Bool
    var chankan: Bool
    var doraCount: Int
    var uraDoraCount: Int
    var handKind: HandKind = .standard
    var concealedTiles: [String] = []
}

struct YakuEntry {
    var name: String
    var han: Int
}

struct YakuResult {
    var yakuList: [YakuEntry]
    var han: Int
    var fu: Int
    var yakuman: Bool
    var yakumanCount: Int
}

func isYakuhaiTile(_ typeId: String, _ seatWind: String, _ roundWind: String) -> Bool {
    let t = TILE_TYPES_BY_ID[typeId]!
    if t.category == .dragon { return true }
    if t.category == .wind { return typeId == seatWind || typeId == roundWind }
    return false
}

func yakuhaiHanForTile(_ typeId: String, _ seatWind: String, _ roundWind: String) -> Int {
    let t = TILE_TYPES_BY_ID[typeId]!
    var han = 0
    if t.category == .dragon { han += 1 }
    if t.category == .wind && typeId == seatWind { han += 1 }
    if t.category == .wind && typeId == roundWind { han += 1 }
    return han
}

private func findWinningGroup(_ groups: [HandGroup], _ winTile: String) -> HandGroup? {
    groups.first { $0.tiles.contains(winTile) }
}

/// Ryanmen (two-sided) wait check for a sequence group containing winTile.
private func isRyanmenWait(_ group: HandGroup, _ winTile: String) -> Bool {
    guard group.kind == .sequence else { return false }
    let ranks = group.tiles.compactMap { rankOf($0) }.sorted()
    guard let winRank = rankOf(winTile), ranks.count == 3 else { return false }
    let isEdge = (ranks[0] == 1 && winRank == 3) || (ranks[0] == 7 && winRank == 9)
    if isEdge { return false }
    let isMiddle = winRank == ranks[1]
    return !isMiddle
}

/// Evaluates one decomposition of a winning hand. Returns nil if the hand has zero yaku
/// (required to win).
func evaluateDecomposition(_ decomp: Decomposition, _ ctx: WinContext) -> YakuResult? {
    let pair = decomp.pair
    let groups = decomp.groups
    var yakuList: [YakuEntry] = []
    var yakumanCount = 0

    let allSimples: [String] = (ctx.handKind == .chiitoitsu || ctx.handKind == .kokushi)
        ? ctx.concealedTiles
        : [pair] + groups.flatMap { $0.tiles }
    let suitsUsed = Set(allSimples.filter { TILE_TYPES_BY_ID[$0]!.category == .suit }.map { SUIT_OF[$0]! })
    let hasHonor = allSimples.contains { isHonor($0) }
    let hasTerminal = allSimples.contains { isTerminal($0) }
    let allTerminalOrHonor = allSimples.allSatisfy { isTerminalOrHonor($0) }
    let allSequences = groups.allSatisfy { $0.kind == .sequence }
    let allTriplets = groups.allSatisfy { $0.kind == .triplet }
    let concealedTripletCount = groups.filter { $0.kind == .triplet && ($0.meld == nil || $0.meld!.concealed) }.count

    // ---- Yakuman (checked first; if any apply, regular yaku are ignored) ----
    if ctx.handKind == .kokushi {
        yakuList.append(YakuEntry(name: "Kokushi Musou", han: 13))
        yakumanCount += 1
    }
    if ctx.concealed && allTriplets && concealedTripletCount == 4 {
        yakuList.append(YakuEntry(name: "Suuankou", han: 13))
        yakumanCount += 1
    }
    if allTerminalOrHonor && hasHonor && !hasTerminal && suitsUsed.isEmpty {
        yakuList.append(YakuEntry(name: "Tsuuiisou", han: 13))
        yakumanCount += 1
    }
    if allTerminalOrHonor && !hasHonor {
        yakuList.append(YakuEntry(name: "Chinroutou", han: 13))
        yakumanCount += 1
    }
    if allSimples.allSatisfy({ GREEN_TILES.contains($0) }) {
        yakuList.append(YakuEntry(name: "Ryuuiisou", han: 13))
        yakumanCount += 1
    }
    do {
        let dragonTriplets = groups.filter { $0.kind == .triplet && TILE_TYPES_BY_ID[$0.tiles[0]]!.category == .dragon }
        if dragonTriplets.count == 3 { yakuList.append(YakuEntry(name: "Daisangen", han: 13)); yakumanCount += 1 }
    }
    do {
        let kanCount = ctx.openMelds.filter { $0.kind == .kan }.count
        if kanCount >= 4 {
            yakuList.append(YakuEntry(name: "Suukantsu", han: 13))
            yakumanCount += 1
        }
    }

    if yakumanCount > 0 {
        let han = yakuList.reduce(0) { $0 + $1.han }
        return YakuResult(yakuList: yakuList, han: han, fu: 20, yakuman: true, yakumanCount: yakumanCount)
    }

    // ---- Regular yaku ----
    if ctx.handKind == .chiitoitsu {
        yakuList.append(YakuEntry(name: "Chiitoitsu", han: 2))
    }

    if ctx.doubleRiichi { yakuList.append(YakuEntry(name: "Double Riichi", han: 2)) }
    else if ctx.riichi { yakuList.append(YakuEntry(name: "Riichi", han: 1)) }
    if ctx.riichi && ctx.ippatsu { yakuList.append(YakuEntry(name: "Ippatsu", han: 1)) }
    if ctx.concealed && ctx.winType == .tsumo && ctx.handKind != .chiitoitsu { yakuList.append(YakuEntry(name: "Menzen Tsumo", han: 1)) }
    if ctx.haitei { yakuList.append(YakuEntry(name: "Haitei Raoyue", han: 1)) }
    if ctx.houtei { yakuList.append(YakuEntry(name: "Houtei Raoyui", han: 1)) }
    if ctx.rinshan { yakuList.append(YakuEntry(name: "Rinshan Kaihou", han: 1)) }
    if ctx.chankan { yakuList.append(YakuEntry(name: "Chankan", han: 1)) }

    if ctx.handKind == .standard {
        if !hasHonor && !hasTerminal { yakuList.append(YakuEntry(name: "Tanyao", han: 1)) }

        for g in groups where g.kind == .triplet {
            let han = yakuhaiHanForTile(g.tiles[0], ctx.seatWind, ctx.roundWind)
            if han > 0 { yakuList.append(YakuEntry(name: "Yakuhai (\(g.tiles[0]))", han: han)) }
        }

        if ctx.concealed && allSequences {
            let winGroup = findWinningGroup(groups, ctx.winTile)
            let pairIsYakuhai = isYakuhaiTile(pair, ctx.seatWind, ctx.roundWind)
            if let winGroup, !pairIsYakuhai, isRyanmenWait(winGroup, ctx.winTile) {
                yakuList.append(YakuEntry(name: "Pinfu", han: 1))
            }
        }

        if allSequences {
            let seqKeys = groups.map { "\(SUIT_OF[$0.tiles[0]]!)-\(rankOf($0.tiles[0])!)" }
            var counts: [String: Int] = [:]
            for k in seqKeys { counts[k, default: 0] += 1 }
            if counts.values.contains(where: { $0 >= 2 }) {
                yakuList.append(YakuEntry(name: "Iipeiko", han: ctx.concealed ? 1 : 0))
            }

            let suitOrder = ["characters", "bamboo", "circle"]
            let startRanks: [Int?] = suitOrder.map { suit in
                groups.first { SUIT_OF[$0.tiles[0]] == suit }.flatMap { rankOf($0.tiles[0]) }
            }
            if startRanks.allSatisfy({ $0 != nil }), startRanks[0] == startRanks[1], startRanks[1] == startRanks[2] {
                yakuList.append(YakuEntry(name: "Sanshoku Doujun", han: ctx.concealed ? 2 : 1))
            }

            for suit in suitOrder {
                let ranksInSuit = groups.filter { SUIT_OF[$0.tiles[0]] == suit }.compactMap { rankOf($0.tiles[0]) }
                if [1, 4, 7].allSatisfy({ ranksInSuit.contains($0) }) {
                    yakuList.append(YakuEntry(name: "Ittsu", han: ctx.concealed ? 2 : 1))
                }
            }
        }

        if allTriplets {
            yakuList.append(YakuEntry(name: "Toitoi", han: 2))
            var suitTripletRanks: [Int: Set<String>] = [:]
            for g in groups {
                let t = TILE_TYPES_BY_ID[g.tiles[0]]!
                if t.category == .suit, let rank = t.rank {
                    suitTripletRanks[rank, default: []].insert(SUIT_OF[g.tiles[0]]!)
                }
            }
            if suitTripletRanks.values.contains(where: { $0.count == 3 }) {
                yakuList.append(YakuEntry(name: "Sanshoku Doukou", han: 2))
            }
        }
        if concealedTripletCount == 3 { yakuList.append(YakuEntry(name: "Sanankou", han: 2)) }

        let chantaShape: Bool = {
            var groupsForCheck: [[String]] = [[pair]]
            groupsForCheck.append(contentsOf: groups.map { $0.tiles })
            return groupsForCheck.allSatisfy { grp in grp.contains { isTerminalOrHonor($0) } }
        }()
        if chantaShape {
            if !hasHonor { yakuList.append(YakuEntry(name: "Junchan", han: ctx.concealed ? 3 : 2)) }
            else { yakuList.append(YakuEntry(name: "Chanta", han: ctx.concealed ? 2 : 1)) }
        }
    }

    if hasHonor && suitsUsed.count == 1 { yakuList.append(YakuEntry(name: "Honitsu", han: ctx.concealed ? 3 : 2)) }
    else if !hasHonor && suitsUsed.count == 1 { yakuList.append(YakuEntry(name: "Chinitsu", han: ctx.concealed ? 6 : 5)) }

    do {
        let dragonTriplets = groups.filter { $0.kind == .triplet && TILE_TYPES_BY_ID[$0.tiles[0]]!.category == .dragon }.count
        let dragonPair = TILE_TYPES_BY_ID[pair]?.category == .dragon
        if dragonTriplets == 2 && dragonPair { yakuList.append(YakuEntry(name: "Shousangen", han: 2)) }
    }

    if yakuList.isEmpty { return nil }

    let han = yakuList.reduce(0) { $0 + $1.han } + ctx.doraCount + ctx.uraDoraCount
    let fu = calculateFu(decomp, ctx)
    return YakuResult(yakuList: yakuList, han: han, fu: fu, yakuman: false, yakumanCount: 0)
}

func calculateFu(_ decomp: Decomposition, _ ctx: WinContext) -> Int {
    if ctx.handKind == .chiitoitsu { return 25 }

    let pair = decomp.pair
    let groups = decomp.groups
    let isPinfu = ctx.concealed && groups.allSatisfy { $0.kind == .sequence }

    if isPinfu { return ctx.winType == .ron ? 30 : 20 }

    var fu = 20
    if ctx.concealed && ctx.winType == .ron { fu += 10 }
    if ctx.winType == .tsumo { fu += 2 }

    for g in groups where g.kind == .triplet {
        let termHonor = isTerminalOrHonor(g.tiles[0])
        let concealedGroup = g.meld == nil || g.meld!.concealed
        let isKanGroup = g.meld?.kind == .kan
        if isKanGroup {
            fu += termHonor ? (concealedGroup ? 32 : 16) : (concealedGroup ? 16 : 8)
        } else {
            fu += termHonor ? (concealedGroup ? 8 : 4) : (concealedGroup ? 4 : 2)
        }
    }

    if isYakuhaiTile(pair, ctx.seatWind, ctx.roundWind) {
        fu += 2 * yakuhaiHanForTile(pair, ctx.seatWind, ctx.roundWind)
    }

    if pair == ctx.winTile && groups.allSatisfy({ !$0.tiles.contains(ctx.winTile) }) {
        fu += 2 // tanki
    } else if let winGroup = findWinningGroup(groups, ctx.winTile) {
        if winGroup.kind == .sequence && !isRyanmenWait(winGroup, ctx.winTile) { fu += 2 } // kanchan/penchan
    }

    return Int(ceil(Double(fu) / 10)) * 10
}

/// Tries every decomposition and returns the highest-scoring valid result.
func bestYakuResult(_ winCheck: WinCheck, _ concealedTiles: [String], _ ctx: WinContext) -> YakuResult? {
    if winCheck.kind == .chiitoitsu || winCheck.kind == .kokushi {
        var c = ctx
        c.handKind = winCheck.kind!
        c.concealedTiles = concealedTiles
        return evaluateDecomposition(Decomposition(pair: "", groups: []), c)
    }
    var best: YakuResult?
    for decomp in winCheck.decompositions {
        var c = ctx
        c.handKind = .standard
        if let result = evaluateDecomposition(decomp, c) {
            if best == nil || compareResults(result, best!) > 0 { best = result }
        }
    }
    return best
}

private func compareResults(_ a: YakuResult, _ b: YakuResult) -> Int {
    if a.yakuman != b.yakuman { return a.yakuman ? 1 : -1 }
    if a.yakuman { return a.yakumanCount - b.yakumanCount }
    if a.han != b.han { return a.han - b.han }
    return a.fu - b.fu
}
