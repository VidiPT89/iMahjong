import Foundation

/// Traditional 4-player Riichi turn engine — pure state machine, no UI or network code.
/// One instance plays exactly one hand (deal to win/draw); LocalMatch chains hands
/// together with dealer rotation and point totals.
///
/// Deliberate scope simplifications (documented, not accidental gaps):
/// - No abortive draws (four-riichi, four-kan, nine-terminals, four-wind).
/// - Multi-ron pays each winner in full from the discarder (no atama-hane).
/// - Added-kan chankan is supported; a 5th kan is disallowed outright.

func isTenpaiWithMelds(_ concealedTiles: [String], _ melds: [Meld]) -> Bool {
    for type in STANDARD_TYPE_IDS {
        if checkWin(concealedTiles + [type], melds).win { return true }
    }
    return false
}

func chiOptionsFor(_ hand: [String], _ tile: String) -> [[String]] {
    guard let rank = rankOf(tile) else { return [] }
    let prefix = String(tile.first!)
    func has(_ r: Int) -> Bool { hand.contains("\(prefix)\(r)") }
    var options: [[String]] = []
    if rank >= 3 && has(rank - 2) && has(rank - 1) { options.append(["\(prefix)\(rank - 2)", "\(prefix)\(rank - 1)"]) }
    if rank >= 2 && rank <= 8 && has(rank - 1) && has(rank + 1) { options.append(["\(prefix)\(rank - 1)", "\(prefix)\(rank + 1)"]) }
    if rank <= 7 && has(rank + 1) && has(rank + 2) { options.append(["\(prefix)\(rank + 1)", "\(prefix)\(rank + 2)"]) }
    return options
}

func countInHand(_ hand: [String], _ type: String) -> Int { hand.filter { $0 == type }.count }

final class RiichiSeat {
    let seatIndex: Int
    var wind: String
    var hand: [String]
    var melds: [Meld] = []
    var discards: [String] = []
    var riichi = false
    var doubleRiichi = false
    var ippatsuActive = false
    var justDeclaredRiichi = false
    var furitenUntilNextDraw = false
    var points: Int

    init(seatIndex: Int, wind: String, hand: [String], points: Int) {
        self.seatIndex = seatIndex
        self.wind = wind
        self.hand = hand.sorted()
        self.points = points
    }
}

enum EnginePhase { case draw, discard, reaction, ended }

struct ReactionOptions {
    var ron = false
    var pon = false
    var kan = false
    var chi: [[String]] = []
}

struct EvaluatedWin {
    var yakuList: [YakuEntry]
    var han: Int
    var fu: Int
    var yakuman: Bool
    var yakumanCount: Int
    var base: Int
    var total: Int
    var payments: ScorePayments
    var concealedAtWin: [String]
}

struct HandResult {
    enum Kind { case tsumo, ron, exhaustive }
    var kind: Kind
    var tsumoSeat: Int?
    var tsumoWin: EvaluatedWin?
    var ronDiscarder: Int?
    var ronWinners: [(seat: Int, win: EvaluatedWin)] = []
    var tenpaiSeats: [Int] = []
    var notenSeats: [Int] = []
    var exhaustivePayments: [Int: Int] = [:]
    var dealerTenpai: Bool = false
}

enum ReactionResponse: Equatable {
    case ron, pon, kan, pass
    case chi(String, String)
}

enum ReactionResolution {
    case ron
    case called(kind: String, seat: Int)
    case advance(nextSeat: Int)
}

final class RiichiEngine {
    var liveWall: [RiichiTile]
    var deadWall: [RiichiTile]
    let dealerSeat: Int
    let roundWind: String
    var doraRevealedCount = 1
    var uraDoraRevealedCount = 1
    var kanCount = 0
    var seats: [RiichiSeat]
    var currentSeat: Int
    var phase: EnginePhase = .draw
    var lastDiscard: (seat: Int, tile: String)?
    var turnDrawnTile: String?
    var isRinshanDraw = false
    var result: HandResult?

    private var chankanActive = false
    private var chankanTile: String?
    private var chankanSeat: Int?

    init(dealerSeat: Int = 0, roundWind: String = "wE", seatWinds: [String]? = nil, points: [Int]? = nil) {
        let dealt = dealWall()
        self.liveWall = dealt.liveWall
        self.deadWall = dealt.deadWall
        self.dealerSeat = dealerSeat
        self.roundWind = roundWind

        let baseOrder = ["wE", "wS", "wW", "wN"]
        let winds = seatWinds ?? (0..<4).map { baseOrder[($0 - dealerSeat + 4) % 4] }
        self.seats = (0..<4).map { i in
            RiichiSeat(
                seatIndex: i,
                wind: winds[i],
                hand: dealt.hands[i].map { $0.typeId },
                points: points?[i] ?? 25000
            )
        }
        self.currentSeat = dealerSeat
    }

    func seat(_ i: Int) -> RiichiSeat { seats[i] }
    func activeSeat() -> RiichiSeat { seats[currentSeat] }

    func doraIndicators() -> [String] { deadWall.prefix(doraRevealedCount).map { $0.typeId } }
    func uraDoraIndicators() -> [String] { Array(deadWall[7..<min(7 + uraDoraRevealedCount, deadWall.count)]).map { $0.typeId } }

    func doraTypeFor(_ indicator: String) -> String {
        let t = TILE_TYPES_BY_ID[indicator]!
        if t.category == .suit {
            let nextRank = t.rank == 9 ? 1 : t.rank! + 1
            return "\(indicator.first!)\(nextRank)"
        }
        if t.category == .wind {
            let order = ["wE", "wS", "wW", "wN"]
            let idx = order.firstIndex(of: indicator)!
            return order[(idx + 1) % 4]
        }
        let order = ["dR", "dG", "dW"]
        let idx = order.firstIndex(of: indicator)!
        return order[(idx + 1) % 3]
    }

    func countDora(_ concealedTiles: [String], _ melds: [Meld], _ indicators: [String]) -> Int {
        let doraTypes = Set(indicators.map { doraTypeFor($0) })
        let allTiles = concealedTiles + melds.flatMap { $0.tiles }
        return allTiles.filter { doraTypes.contains($0) }.count
    }

    enum DrawOutcome {
        case exhaustive(HandResult)
        case drawn(seat: Int, tile: String, rinshan: Bool)
    }

    /// Draws the next tile for the active seat (from live wall, or dead wall after a kan).
    func draw() -> DrawOutcome {
        let fromDead = isRinshanDraw
        if !fromDead && liveWall.isEmpty {
            let r = buildExhaustiveDraw()
            result = r
            phase = .ended
            return .exhaustive(r)
        }
        let tile: RiichiTile
        if fromDead {
            tile = deadWall.removeLast()
        } else {
            tile = liveWall.removeLast()
        }
        // Dead wall stays at 14 tiles: after a kan draw, pull the live wall's last tile
        // into the dead wall to replenish it.
        if fromDead && !liveWall.isEmpty { deadWall.insert(liveWall.removeLast(), at: 0) }

        let s = activeSeat()
        s.hand.append(tile.typeId)
        s.hand.sort()
        turnDrawnTile = tile.typeId
        phase = .discard
        return .drawn(seat: currentSeat, tile: tile.typeId, rinshan: fromDead)
    }

    func canDeclareTsumo() -> Bool {
        // Tsumo (and kan, see canAnkan) require a self-draw — right after calling
        // pon/chi on someone else's discard you owe an immediate discard, not a win.
        guard turnDrawnTile != nil else { return false }
        let s = activeSeat()
        let wc = checkWin(s.hand, s.melds)
        guard wc.win else { return false }
        return evaluateWin(s, wc, turnDrawnTile!, .tsumo) != nil
    }

    @discardableResult
    func declareTsumo() -> HandResult? {
        guard canDeclareTsumo() else { return nil }
        let s = activeSeat()
        let wc = checkWin(s.hand, s.melds)
        guard let win = evaluateWin(s, wc, turnDrawnTile!, .tsumo) else { return nil }
        let r = HandResult(kind: .tsumo, tsumoSeat: currentSeat, tsumoWin: win)
        result = r
        phase = .ended
        return r
    }

    func evaluateWin(_ s: RiichiSeat, _ winCheck: WinCheck, _ winTile: String, _ winType: WinType) -> EvaluatedWin? {
        let concealed = winType == .ron ? s.hand + [winTile] : s.hand
        var ctx = WinContext(
            concealed: s.melds.allSatisfy { $0.concealed },
            openMelds: s.melds,
            winTile: winTile,
            winType: winType,
            seatWind: s.wind,
            roundWind: roundWind,
            riichi: s.riichi,
            doubleRiichi: s.doubleRiichi,
            ippatsu: s.ippatsuActive,
            haitei: winType == .tsumo && liveWall.isEmpty && !isRinshanDraw,
            houtei: winType == .ron && liveWall.isEmpty,
            rinshan: winType == .tsumo && isRinshanDraw,
            chankan: chankanActive,
            doraCount: 0,
            uraDoraCount: 0
        )
        ctx.doraCount = countDora(concealed, s.melds, doraIndicators())
        ctx.uraDoraCount = s.riichi ? countDora(concealed, s.melds, uraDoraIndicators()) : 0

        guard let best = bestYakuResult(winCheck, concealed, ctx) else { return nil }
        let score = scorePoints(best, isDealer: s.seatIndex == dealerSeat, winType: winType)
        return EvaluatedWin(
            yakuList: best.yakuList, han: best.han, fu: best.fu, yakuman: best.yakuman, yakumanCount: best.yakumanCount,
            base: score.base, total: score.total, payments: score.payments, concealedAtWin: concealed
        )
    }

    /// Checks ron eligibility for `seatIndex` against the current lastDiscard, respecting furiten.
    func canRon(_ seatIndex: Int) -> Bool {
        let s = seats[seatIndex]
        guard let last = lastDiscard, last.seat != seatIndex else { return false }
        let tile = last.tile
        if s.discards.contains(tile) { return false } // permanent furiten
        if s.furitenUntilNextDraw { return false }
        let wc = checkWin(s.hand + [tile], s.melds)
        guard wc.win else { return false }
        return evaluateWin(s, wc, tile, .ron) != nil
    }

    @discardableResult
    func discard(_ tile: String) -> [Int: ReactionOptions] {
        let s = activeSeat()
        guard let idx = s.hand.firstIndex(of: tile) else { fatalError("Tile \(tile) not in hand") }
        s.hand.remove(at: idx)
        s.discards.append(tile)
        lastDiscard = (seat: currentSeat, tile: tile)
        isRinshanDraw = false
        turnDrawnTile = nil

        if s.riichi { s.ippatsuActive = s.justDeclaredRiichi }
        s.justDeclaredRiichi = false

        phase = .reaction
        return getReactionSummary()
    }

    func getReactionSummary() -> [Int: ReactionOptions] {
        var summary: [Int: ReactionOptions] = [:]
        guard let last = lastDiscard else { return summary }
        for i in 0..<4 {
            if i == last.seat { continue }
            let s = seats[i]
            var opts = ReactionOptions(ron: canRon(i))
            // Once riichi is declared the hand is locked — no more calls, only ron.
            if !s.riichi {
                let cnt = countInHand(s.hand, last.tile)
                opts.pon = cnt >= 2
                opts.kan = cnt >= 3
                if i == (last.seat + 1) % 4 { opts.chi = chiOptionsFor(s.hand, last.tile) }
            }
            summary[i] = opts
        }
        return summary
    }

    /// Marks a seat as having declined an available ron (temporary furiten).
    func markPassedRon(_ seatIndex: Int) {
        seats[seatIndex].furitenUntilNextDraw = true
    }

    /// Resolves one discard's reaction window given each seat's declared intent.
    /// Applies standard priority: ron > pon/kan > chi > nothing.
    func resolveReactions(_ responses: [Int: ReactionResponse]) -> ReactionResolution {
        // Re-validate every claimed action against freshly-computed legality — never
        // trust `responses` at face value (it may come from an untrusted network client
        // in online play).
        let summary = getReactionSummary()

        let ronSeats = responses.keys.sorted().filter { responses[$0] == .ron && canRon($0) }
        if !ronSeats.isEmpty {
            let winners: [(seat: Int, win: EvaluatedWin)] = ronSeats.compactMap { i in
                let s = seats[i]
                let wc = checkWin(s.hand + [lastDiscard!.tile], s.melds)
                guard let win = evaluateWin(s, wc, lastDiscard!.tile, .ron) else { return nil }
                return (seat: i, win: win)
            }
            let r = HandResult(kind: .ron, ronDiscarder: lastDiscard!.seat, ronWinners: winners)
            result = r
            phase = .ended
            return .ron
        }

        for (i, response) in responses {
            if response == .pass && canRon(i) { seats[i].furitenUntilNextDraw = true }
        }

        if let ponSeat = responses.keys.sorted().first(where: { i in
            (responses[i] == .pon && summary[i]?.pon == true) || (responses[i] == .kan && summary[i]?.kan == true)
        }) {
            breakAllIppatsu()
            if responses[ponSeat] == .kan { return callDaiminkan(ponSeat) }
            return callPon(ponSeat)
        }

        if let chiSeat = responses.keys.sorted().first(where: { i -> Bool in
            guard case .chi(let a, let b)? = responses[i] else { return false }
            return summary[i]?.chi.contains { $0[0] == a && $0[1] == b } ?? false
        }) {
            breakAllIppatsu()
            guard case .chi(let a, let b) = responses[chiSeat]! else { fatalError() }
            return callChi(chiSeat, [a, b])
        }

        breakAllIppatsu()
        currentSeat = (lastDiscard!.seat + 1) % 4
        phase = .draw
        return .advance(nextSeat: currentSeat)
    }

    func breakAllIppatsu() {
        seats.forEach { $0.ippatsuActive = false }
    }

    /// Physically removes the just-made discard from the pile — it moves into a meld.
    @discardableResult
    private func takeLastDiscardIntoMeld() -> String? {
        let discarder = seats[lastDiscard!.seat]
        return discarder.discards.popLast()
    }

    func callChi(_ seatIndex: Int, _ usingTiles: [String]) -> ReactionResolution {
        let s = seats[seatIndex]
        let tile = lastDiscard!.tile
        for t in usingTiles {
            if let idx = s.hand.firstIndex(of: t) { s.hand.remove(at: idx) }
        }
        s.melds.append(Meld(kind: .chi, tiles: (usingTiles + [tile]).sorted(), concealed: false))
        takeLastDiscardIntoMeld()
        currentSeat = seatIndex
        phase = .discard
        isRinshanDraw = false
        return .called(kind: "chi", seat: seatIndex)
    }

    func callPon(_ seatIndex: Int) -> ReactionResolution {
        let s = seats[seatIndex]
        let tile = lastDiscard!.tile
        for _ in 0..<2 { if let idx = s.hand.firstIndex(of: tile) { s.hand.remove(at: idx) } }
        s.melds.append(Meld(kind: .pon, tiles: [tile, tile, tile], concealed: false))
        takeLastDiscardIntoMeld()
        currentSeat = seatIndex
        phase = .discard
        isRinshanDraw = false
        return .called(kind: "pon", seat: seatIndex)
    }

    func callDaiminkan(_ seatIndex: Int) -> ReactionResolution {
        if kanCount >= 4 { return callPon(seatIndex) } // 5th kan disallowed — degrade to pon
        let s = seats[seatIndex]
        let tile = lastDiscard!.tile
        for _ in 0..<3 { if let idx = s.hand.firstIndex(of: tile) { s.hand.remove(at: idx) } }
        s.melds.append(Meld(kind: .kan, tiles: [tile, tile, tile, tile], concealed: false))
        takeLastDiscardIntoMeld()
        kanCount += 1
        doraRevealedCount += 1
        currentSeat = seatIndex
        isRinshanDraw = true
        phase = .draw
        return .called(kind: "daiminkan", seat: seatIndex)
    }

    func canAnkan(_ seatIndex: Int) -> [String] {
        // Ankan requires a self-draw, same as tsumo.
        guard seatIndex == currentSeat, turnDrawnTile != nil else { return [] }
        let s = seats[seatIndex]
        // Simplification: ankan after riichi is disallowed outright here (real rules
        // allow it only when it can't change the wait — narrow edge case).
        if s.riichi { return [] }
        return STANDARD_TYPE_IDS.filter { countInHand(s.hand, $0) == 4 }
    }

    @discardableResult
    func callAnkan(_ seatIndex: Int, _ type: String) -> ReactionResolution? {
        if kanCount >= 4 { return nil }
        guard canAnkan(seatIndex).contains(type) else { return nil }
        let s = seats[seatIndex]
        for _ in 0..<4 { if let idx = s.hand.firstIndex(of: type) { s.hand.remove(at: idx) } }
        s.melds.append(Meld(kind: .kan, tiles: [type, type, type, type], concealed: true))
        kanCount += 1
        doraRevealedCount += 1
        isRinshanDraw = true
        phase = .draw
        return .called(kind: "ankan", seat: seatIndex)
    }

    func canShouminkan(_ seatIndex: Int) -> [String] {
        let s = seats[seatIndex]
        return s.melds.filter { $0.kind == .pon && s.hand.contains($0.tiles[0]) }.map { $0.tiles[0] }
    }

    /// Upgrades an existing pon to a kan; other seats may chankan (rob the kan) before it resolves.
    @discardableResult
    func callShouminkan(_ seatIndex: Int, _ type: String) -> ReactionResolution? {
        if kanCount >= 4 { return nil }
        let s = seats[seatIndex]
        guard let meldIdx = s.melds.firstIndex(where: { $0.kind == .pon && $0.tiles[0] == type }) else { return nil }
        s.melds[meldIdx].kind = .kan
        s.melds[meldIdx].tiles = [type, type, type, type]
        if let idx = s.hand.firstIndex(of: type) { s.hand.remove(at: idx) }
        chankanActive = true
        chankanTile = type
        chankanSeat = seatIndex
        kanCount += 1
        doraRevealedCount += 1
        isRinshanDraw = true
        phase = .draw
        return .called(kind: "shouminkan", seat: seatIndex)
    }

    /// Called after callShouminkan if no one robs the kan, to clear the chankan window.
    func clearChankanWindow() {
        chankanActive = false
        chankanTile = nil
        chankanSeat = nil
    }

    func isTenpai(_ seatIndex: Int) -> Bool {
        let s = seats[seatIndex]
        return isTenpaiWithMelds(s.hand, s.melds)
    }

    func canDeclareRiichi(_ seatIndex: Int) -> Bool {
        // Riichi requires it be this seat's own turn, right after their draw.
        guard seatIndex == currentSeat, turnDrawnTile != nil else { return false }
        let s = seats[seatIndex]
        guard s.melds.isEmpty, !s.riichi, liveWall.count >= 4, s.points >= 1000 else { return false }
        return isTenpaiWithMelds(s.hand, [])
    }

    @discardableResult
    func declareRiichi(_ seatIndex: Int) -> Bool {
        guard canDeclareRiichi(seatIndex) else { return false }
        let s = seats[seatIndex]
        s.riichi = true
        s.doubleRiichi = s.discards.isEmpty
        s.justDeclaredRiichi = true
        s.points -= 1000
        return true
    }

    func buildExhaustiveDraw() -> HandResult {
        let tenpaiSeats = (0..<4).filter { isTenpai($0) }
        let notenSeats = (0..<4).filter { !tenpaiSeats.contains($0) }
        var payments: [Int: Int] = [:]
        if !tenpaiSeats.isEmpty && tenpaiSeats.count < 4 {
            let totalPot = 3000
            let perNoten = (totalPot / notenSeats.count / 100) * 100
            let perTenpai = (totalPot / tenpaiSeats.count / 100) * 100
            for i in notenSeats { payments[i] = -perNoten }
            for i in tenpaiSeats { payments[i] = perTenpai }
        } else {
            for i in 0..<4 { payments[i] = 0 }
        }
        return HandResult(
            kind: .exhaustive, tenpaiSeats: tenpaiSeats, notenSeats: notenSeats,
            exhaustivePayments: payments, dealerTenpai: tenpaiSeats.contains(dealerSeat)
        )
    }
}
