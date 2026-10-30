import Foundation

/// Riichi Academy logic: waits, tile acceptance, fu breakdowns and procedurally generated
/// drills. Pure Foundation code, so every answer the app marks as right is unit tested
/// against the same engine that scores the Riichi table.

let SUIT_PREFIXES = ["m", "p", "s"]
let HONOR_IDS = ["wE", "wS", "wW", "wN", "dR", "dG", "dW"]

private let TILE_ORDER: [String: Int] = Dictionary(uniqueKeysWithValues: STANDARD_TYPE_IDS.enumerated().map { ($1, $0) })

func sortTiles(_ tiles: [String]) -> [String] {
    tiles.sorted { (TILE_ORDER[$0] ?? 99) < (TILE_ORDER[$1] ?? 99) }
}

/// Tile types that would complete this hand (13 tiles minus 3 per meld).
func winningTiles(_ hand: [String], _ melds: [Meld] = []) -> [String] {
    STANDARD_TYPE_IDS.filter { checkWin(hand + [$0], melds).win }
}

/// Copies of `waits` the player cannot see anywhere (hand, own melds, discards).
func acceptance(_ waits: [String], visible: [String]) -> Int {
    waits.reduce(0) { total, wait in total + max(0, 4 - countInHand(visible, wait)) }
}

/// Waits already in the player's own discards: with any of them, ron is not allowed.
func furitenTiles(waits: [String], discards: [String]) -> [String] {
    waits.filter { discards.contains($0) }
}

struct DiscardOption {
    let tile: String
    let waits: [String]
    let acceptance: Int
}

/// Every distinct discard from a hand that has just drawn, with the waits it leaves.
func discardOptions(_ hand: [String], _ melds: [Meld] = [], visible: [String] = []) -> [DiscardOption] {
    let seen = hand + visible + melds.flatMap(\.tiles)
    return sortTiles(Array(Set(hand))).map { tile in
        var rest = hand
        rest.remove(at: rest.firstIndex(of: tile)!)
        let waits = winningTiles(rest, melds)
        return DiscardOption(tile: tile, waits: waits, acceptance: acceptance(waits, visible: seen))
    }
}

/// Discards that reach tenpai with the most winning tiles left; empty when none do.
func bestDiscards(_ options: [DiscardOption]) -> Set<String> {
    let best = options.map(\.acceptance).max() ?? 0
    guard best > 0 else { return [] }
    return Set(options.filter { $0.acceptance == best }.map(\.tile))
}

// MARK: - Random hands

/// SplitMix64, so drills can be replayed from a seed in tests.
struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

/// A random complete closed hand (4 groups + pair) from the given suits and, optionally,
/// the honors. Respects the four-copies limit.
func randomCompleteHand<G: RandomNumberGenerator>(suits: [String], honors: Bool, using rng: inout G) -> [String] {
    let singles = suits.flatMap { suit in (1...9).map { "\(suit)\($0)" } } + (honors ? HONOR_IDS : [])
    while true {
        var tiles: [String] = []
        for _ in 0..<4 {
            if Int.random(in: 0..<3, using: &rng) > 0, let suit = suits.randomElement(using: &rng) {
                let start = Int.random(in: 1...7, using: &rng)
                tiles += (start...start + 2).map { "\(suit)\($0)" }
            } else {
                let tile = singles.randomElement(using: &rng)!
                tiles += [tile, tile, tile]
            }
        }
        let pair = singles.randomElement(using: &rng)!
        tiles += [pair, pair]
        if countsFromTiles(tiles).values.allSatisfy({ $0 <= 4 }) { return sortTiles(tiles) }
    }
}

// MARK: - Drills

enum DrillKind: String, CaseIterable {
    case waits, discard, score
}

struct WaitDrill {
    let hand: [String]
    let choices: [String]
    let waits: [String]
}

/// Level 0 mixes suits and honors (one or two waits); level 1 uses a single suit, where
/// multi-sided waits are common and hard to spot.
func makeWaitDrill<G: RandomNumberGenerator>(level: Int, using rng: inout G) -> WaitDrill {
    let suit = SUIT_PREFIXES.randomElement(using: &rng)!
    let complete = level == 0
        ? randomCompleteHand(suits: SUIT_PREFIXES, honors: true, using: &rng)
        : randomCompleteHand(suits: [suit], honors: false, using: &rng)
    var hand = complete
    hand.remove(at: Int.random(in: 0..<hand.count, using: &rng))
    let waits = winningTiles(hand)
    let choices: [String]
    if level == 0 {
        var near = Set(waits)
        for tile in hand {
            near.insert(tile)
            if let rank = rankOf(tile) {
                for r in max(1, rank - 2)...min(9, rank + 2) { near.insert("\(tile.first!)\(r)") }
            }
        }
        choices = sortTiles(Array(near))
    } else {
        choices = (1...9).map { "\(suit)\($0)" }
    }
    return WaitDrill(hand: hand, choices: choices, waits: waits)
}

struct DiscardDrill {
    let hand: [String]
    let options: [DiscardOption]
    let best: Set<String>
}

func makeDiscardDrill<G: RandomNumberGenerator>(using rng: inout G) -> DiscardDrill {
    while true {
        let suits = Array(SUIT_PREFIXES.shuffled(using: &rng).prefix(Int.random(in: 1...3, using: &rng)))
        var hand = randomCompleteHand(suits: suits, honors: Bool.random(using: &rng), using: &rng)
        hand.remove(at: Int.random(in: 0..<hand.count, using: &rng))
        let extra = STANDARD_TYPE_IDS.randomElement(using: &rng)!
        guard countInHand(hand, extra) < 4 else { continue }
        let full = sortTiles(hand + [extra])
        guard !checkWin(full, []).win else { continue }
        let options = discardOptions(full)
        let best = bestDiscards(options)
        // Only keep real decisions: at least one tenpai discard, and some that are worse.
        guard !best.isEmpty, best.count < options.count else { continue }
        return DiscardDrill(hand: full, options: options, best: best)
    }
}

// MARK: - Scoring

/// The highest-scoring reading of a closed winning hand, with the decomposition and wait
/// that produced it, so the fu can be explained piece by piece.
struct BestEvaluation {
    let result: YakuResult
    let decomposition: Decomposition?
    let context: WinContext
}

func bestEvaluation(_ hand: [String], _ ctx: WinContext) -> BestEvaluation? {
    let winCheck = checkWin(hand, ctx.openMelds)
    guard winCheck.win else { return nil }
    var best: BestEvaluation?
    func consider(_ result: YakuResult?, _ decomp: Decomposition?, _ c: WinContext) {
        guard let result else { return }
        if best == nil || compareResults(result, best!.result) > 0 {
            best = BestEvaluation(result: result, decomposition: decomp, context: c)
        }
    }
    if winCheck.kind == .chiitoitsu || winCheck.kind == .kokushi {
        var c = ctx
        c.handKind = winCheck.kind!
        c.concealedTiles = hand
        consider(evaluateDecomposition(Decomposition(pair: "", groups: []), c), nil, c)
    }
    for decomp in winCheck.decompositions {
        var c = ctx
        c.handKind = .standard
        var indices = decomp.groups.indices.filter { decomp.groups[$0].meld == nil && decomp.groups[$0].tiles.contains(ctx.winTile) }
        if decomp.pair == ctx.winTile { indices.append(-1) }
        for index in indices {
            c.winningGroupIndex = index
            consider(evaluateDecomposition(decomp, c), decomp, c)
        }
    }
    return best
}

enum WaitShape: String { case ryanmen, kanchan, penchan, shanpon, tanki }

enum FuPart: Equatable {
    case base(Int)
    case pinfu(Int)
    case sevenPairs
    case closedRon
    case tsumo
    case triplet(tile: String, concealed: Bool, fu: Int)
    case valuePair(tile: String, fu: Int)
    case wait(WaitShape, fu: Int)

    var fu: Int {
        switch self {
        case .base(let fu), .pinfu(let fu): return fu
        case .sevenPairs: return 25
        case .closedRon: return 10
        case .tsumo: return 2
        case .triplet(_, _, let fu), .valuePair(_, let fu), .wait(_, let fu): return fu
        }
    }
}

func waitShape(_ eval: BestEvaluation) -> WaitShape? {
    guard let decomp = eval.decomposition, let index = eval.context.winningGroupIndex else { return nil }
    if index == -1 { return .tanki }
    let group = decomp.groups[index]
    if group.kind == .triplet { return .shanpon }
    let ranks = group.tiles.compactMap { rankOf($0) }.sorted()
    guard let win = rankOf(eval.context.winTile), ranks.count == 3 else { return nil }
    if win == ranks[1] { return .kanchan }
    if (ranks[0] == 1 && win == 3) || (ranks[0] == 7 && win == 7) { return .penchan }
    return .ryanmen
}

/// The fu of a closed hand, itemised the same way `calculateFu` adds it up.
func fuBreakdown(_ eval: BestEvaluation) -> [FuPart] {
    let ctx = eval.context
    if ctx.handKind == .chiitoitsu { return [.sevenPairs] }
    guard let decomp = eval.decomposition else { return [] }
    if eval.result.yakuList.contains(where: { $0.name == "Pinfu" }) {
        return [.pinfu(ctx.winType == .ron ? 30 : 20)]
    }
    var parts: [FuPart] = [.base(20)]
    if ctx.concealed && ctx.winType == .ron { parts.append(.closedRon) }
    if ctx.winType == .tsumo { parts.append(.tsumo) }
    for (index, group) in decomp.groups.enumerated() where group.kind == .triplet {
        let concealed = (group.meld == nil || group.meld!.concealed) && !(ctx.winType == .ron && ctx.winningGroupIndex == index)
        let base = isTerminalOrHonor(group.tiles[0]) ? 4 : 2
        let kan = group.meld?.kind == .kan ? 4 : 1
        parts.append(.triplet(tile: group.tiles[0], concealed: concealed, fu: base * kan * (concealed ? 2 : 1)))
    }
    let pairHan = yakuhaiHanForTile(decomp.pair, ctx.seatWind, ctx.roundWind)
    if pairHan > 0 { parts.append(.valuePair(tile: decomp.pair, fu: 2 * pairHan)) }
    if let shape = waitShape(eval) {
        parts.append(.wait(shape, fu: [.kanchan, .penchan, .tanki].contains(shape) ? 2 : 0))
    }
    return parts
}

/// Rounds raw fu the way the scoring table does (up to the next 10, minimum 30) — except
/// for the fixed-fu shapes (pinfu, seven pairs).
func roundedFu(_ parts: [FuPart]) -> Int {
    if parts.count == 1, let only = parts.first {
        switch only {
        case .pinfu(let fu): return fu
        case .sevenPairs: return 25
        default: break
        }
    }
    let raw = parts.reduce(0) { $0 + $1.fu }
    return max(30, Int(ceil(Double(raw) / 10)) * 10)
}

struct ScoreDrill {
    let hand: [String]
    let winTile: String
    let winType: WinType
    let isDealer: Bool
    let seatWind: String
    let riichi: Bool
    let doraCount: Int
    let evaluation: BestEvaluation
    let fuParts: [FuPart]
    let payment: ScoreResult
    let choices: [Int]
}

func makeScoreDrill<G: RandomNumberGenerator>(using rng: inout G) -> ScoreDrill {
    while true {
        let hand = randomCompleteHand(suits: SUIT_PREFIXES, honors: Bool.random(using: &rng), using: &rng)
        let winTile = hand.randomElement(using: &rng)!
        let isDealer = Int.random(in: 0..<4, using: &rng) == 0
        let seatWind = isDealer ? "wE" : ["wS", "wW", "wN"].randomElement(using: &rng)!
        let winType: WinType = Bool.random(using: &rng) ? .ron : .tsumo
        let riichi = Int.random(in: 0..<3, using: &rng) == 0
        let dora = [0, 0, 1, 2].randomElement(using: &rng)!
        let ctx = WinContext(
            concealed: true, openMelds: [], winTile: winTile, winType: winType,
            seatWind: seatWind, roundWind: "wE", riichi: riichi, doubleRiichi: false,
            ippatsu: false, haitei: false, houtei: false, rinshan: false,
            doraCount: dora, uraDoraCount: 0
        )
        guard let eval = bestEvaluation(hand, ctx), !eval.result.yakuman, eval.result.han <= 6 else { continue }
        let payment = scorePoints(eval.result, isDealer: isDealer, winType: winType)
        var wrong = Set<Int>()
        for (dh, df) in [(-1, 0), (1, 0), (0, 10), (0, -10), (1, 10), (-1, 10), (2, 0), (0, 20)] {
            var r = eval.result
            r.han += dh
            r.fu += df
            guard r.han >= 1, r.fu >= 20 else { continue }
            let total = scorePoints(r, isDealer: isDealer, winType: winType).total
            if total != payment.total { wrong.insert(total) }
        }
        guard wrong.count >= 3 else { continue }
        let choices = (Array(wrong).shuffled(using: &rng).prefix(3) + [payment.total]).sorted()
        return ScoreDrill(
            hand: hand, winTile: winTile, winType: winType, isDealer: isDealer, seatWind: seatWind,
            riichi: riichi, doraCount: dora, evaluation: eval, fuParts: fuBreakdown(eval),
            payment: payment, choices: choices
        )
    }
}

// MARK: - Progress

/// Lesson completion and drill accuracy, kept on this device only.
final class AcademyProgress: ObservableObject {
    struct DrillStats: Codable, Equatable {
        var answered = 0
        var correct = 0
        var streak = 0
        var bestStreak = 0
    }

    private let defaults: UserDefaults
    private let lessonsKey = "ividimahjong-academy-lessons"
    private func statsKey(_ kind: DrillKind) -> String { "ividimahjong-academy-drill-\(kind.rawValue)" }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var completedLessons: Set<String> {
        Set(defaults.stringArray(forKey: lessonsKey) ?? [])
    }

    func markLessonDone(_ id: String) {
        objectWillChange.send()
        defaults.set(Array(completedLessons.union([id])).sorted(), forKey: lessonsKey)
    }

    func stats(_ kind: DrillKind) -> DrillStats {
        guard let data = defaults.data(forKey: statsKey(kind)),
              let stats = try? JSONDecoder().decode(DrillStats.self, from: data) else { return DrillStats() }
        return stats
    }

    func record(_ kind: DrillKind, correct: Bool) {
        objectWillChange.send()
        var s = stats(kind)
        s.answered += 1
        if correct {
            s.correct += 1
            s.streak += 1
            s.bestStreak = max(s.bestStreak, s.streak)
        } else {
            s.streak = 0
        }
        defaults.set(try? JSONEncoder().encode(s), forKey: statsKey(kind))
    }
}
