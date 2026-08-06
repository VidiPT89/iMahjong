import Foundation
import Combine

/// Orchestrates a full local match (bots + humans on one device): chains RiichiEngine
/// hands together with dealer rotation and running points, and drives bot turns
/// automatically. SwiftUI views observe this ObservableObject and call the human*
/// methods in response to taps.
///
/// Scope simplification: plays a single East round (4 hands, one dealer turn each) — a
/// common casual "tonpuusen" format — rather than a full East+South hanchan.

private let BOT_DELAY: TimeInterval = 0.55

enum MatchEvent {
    case handStart
    case drawn(seat: Int, rinshan: Bool)
    case awaitHumanDiscard
    case awaitHumanReaction(seatIndex: Int, opts: ReactionOptions)
    case discarded(seat: Int, tile: String)
    case called(kind: String, seat: Int)
    case riichi(seat: Int)
    case kan(seat: Int)
    case handEnd(result: HandResult)
    case matchEnd
}

final class LocalMatch: ObservableObject {
    let isHuman: [Bool]
    @Published private(set) var engine: RiichiEngine!
    @Published private(set) var points: [Int] = [25000, 25000, 25000, 25000]
    @Published private(set) var riichiSticksOnTable = 0
    @Published private(set) var matchOver = false
    @Published private(set) var pendingHumanSeats: [Int] = []
    @Published private(set) var awaitingHumanReaction = false
    @Published var lastEvent: MatchEvent?

    private(set) var roundWind = "wE"
    private(set) var handNumber = 1
    private(set) var dealerSeat = 0

    private var pendingReactionResponses: [Int: ReactionResponse] = [:]
    private var gen = 0
    private var lastProgressAt = Date()
    private var watchdog: Timer?

    init(isHuman: [Bool]) {
        self.isHuman = isHuman
        // Deliberately NOT calling startHand() here — mirrors the web version: the
        // caller should call match.startHand() right after construction.
        watchdog = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.watchdogTick()
        }
    }

    deinit { stop() }

    private func watchdogTick() {
        guard !matchOver, let g = engine else { return }
        guard Date().timeIntervalSince(lastProgressAt) >= 2.5 else { return }
        if g.phase == .ended { return }
        if currentSeatIsHuman() && (g.phase == .draw || g.phase == .discard) { return }
        if awaitingHumanReaction { return }
        gen += 1
        lastProgressAt = Date()
        if g.phase == .reaction { resolveReactionPhase() } else { tick() }
    }

    private func emit(_ event: MatchEvent) {
        lastProgressAt = Date()
        objectWillChange.send()
        lastEvent = event
    }

    /// Schedules fn after delay, tagged with the current generation — if the watchdog
    /// invalidates that generation before it fires, it's a no-op.
    private func scheduleAfter(_ delay: TimeInterval, _ fn: @escaping () -> Void) {
        let g = gen
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self, self.gen == g else { return }
            fn()
        }
    }

    func startHand() {
        engine = RiichiEngine(
            dealerSeat: dealerSeat,
            roundWind: roundWind,
            isBot: isHuman.map { !$0 },
            points: points
        )
        emit(.handStart)
        tick()
    }

    func currentSeatIsHuman() -> Bool { isHuman[engine.currentSeat] }

    /// Advances the state machine until it needs human input or the hand ends.
    private func tick() {
        let g = engine!
        if g.phase == .ended { finishHand(); return }

        if g.phase == .draw {
            let wasHuman = currentSeatIsHuman()
            let outcome = g.draw()
            if case .exhaustive = outcome { finishHand(); return }
            if case .drawn(let seat, _, let rinshan) = outcome {
                emit(.drawn(seat: seat, rinshan: rinshan))
            }

            if wasHuman {
                emit(.awaitHumanDiscard)
                return
            }
            scheduleAfter(BOT_DELAY) { [weak self] in self?.runBotTurn() }
            return
        }

        if g.phase == .reaction {
            resolveReactionPhase()
            return
        }

        if g.phase == .discard {
            // Reached right after a pon/chi call (not a draw) — the caller still owes
            // an immediate discard.
            if currentSeatIsHuman() { emit(.awaitHumanDiscard); return }
            scheduleAfter(BOT_DELAY) { [weak self] in self?.runBotTurn() }
        }
    }

    private func runBotTurn() {
        let g = engine!
        if g.canDeclareTsumo() {
            g.declareTsumo()
            finishHand()
            return
        }
        if let ankanType = chooseBotAnkan(g, g.currentSeat) {
            g.callAnkan(g.currentSeat, ankanType)
            emit(.kan(seat: g.currentSeat))
            scheduleAfter(BOT_DELAY) { [weak self] in self?.tick() }
            return
        }
        if chooseBotRiichi(g, g.currentSeat) {
            g.declareRiichi(g.currentSeat)
            emit(.riichi(seat: g.currentSeat))
        }
        let seat = g.activeSeat()
        let tile = seat.riichi ? g.turnDrawnTile! : chooseBotDiscard(seat.hand, seat.melds)
        g.discard(tile)
        emit(.discarded(seat: g.lastDiscard!.seat, tile: tile))
        scheduleAfter(BOT_DELAY) { [weak self] in self?.tick() }
    }

    private func resolveReactionPhase() {
        let g = engine!
        let summary = g.getReactionSummary()
        var responses: [Int: ReactionResponse] = [:]
        // Multiple human seats can simultaneously have a valid reaction (e.g. double
        // ron) — all must be asked, not just one.
        var humanPending: [(seatIndex: Int, opts: ReactionOptions)] = []

        for seatIndex in summary.keys.sorted() {
            let opts = summary[seatIndex]!
            if isHuman[seatIndex] {
                let hasAny = opts.ron || opts.pon || opts.kan || !opts.chi.isEmpty
                if hasAny { humanPending.append((seatIndex, opts)); continue }
                responses[seatIndex] = .pass
                continue
            }
            let decision = chooseBotReaction(g, seatIndex, opts)
            if decision == .ron { responses[seatIndex] = .ron; continue }
            if opts.ron { g.markPassedRon(seatIndex) }
            responses[seatIndex] = decision
        }

        if !humanPending.isEmpty {
            pendingReactionResponses = responses
            pendingHumanSeats = humanPending.map { $0.seatIndex }
            awaitingHumanReaction = true
            for h in humanPending { emit(.awaitHumanReaction(seatIndex: h.seatIndex, opts: h.opts)) }
            return
        }

        applyReactions(responses)
    }

    private func applyReactions(_ responses: [Int: ReactionResponse]) {
        let g = engine!
        let r = g.resolveReactions(responses)
        switch r {
        case .ron:
            finishHand()
        case .called(let kind, let seat):
            emit(.called(kind: kind, seat: seat))
            scheduleAfter(BOT_DELAY) { [weak self] in self?.tick() }
        case .advance:
            scheduleAfter(0.08) { [weak self] in self?.tick() }
        }
    }

    // MARK: - Human actions (called by the UI)

    func humanDiscard(_ tile: String) {
        guard engine.phase == .discard, currentSeatIsHuman() else { return }
        let g = engine!
        g.discard(tile)
        emit(.discarded(seat: g.lastDiscard!.seat, tile: tile))
        scheduleAfter(0.08) { [weak self] in self?.tick() }
    }

    func humanDeclareTsumo() {
        guard currentSeatIsHuman(), engine.declareTsumo() != nil else { return }
        finishHand()
    }

    func humanDeclareRiichi() {
        engine.declareRiichi(engine.currentSeat)
        emit(.riichi(seat: engine.currentSeat))
    }

    func humanAnkan(_ type: String) {
        guard currentSeatIsHuman(), engine.callAnkan(engine.currentSeat, type) != nil else { return }
        emit(.kan(seat: engine.currentSeat))
        scheduleAfter(BOT_DELAY) { [weak self] in self?.tick() }
    }

    func humanReact(_ seatIndex: Int, _ action: ReactionResponse) {
        guard pendingHumanSeats.contains(seatIndex) else { return }
        if action == .pass && engine.canRon(seatIndex) { engine.markPassedRon(seatIndex) }
        pendingReactionResponses[seatIndex] = action
        pendingHumanSeats.removeAll { $0 == seatIndex }
        if !pendingHumanSeats.isEmpty { return } // still waiting on other human seats

        let responses = pendingReactionResponses
        pendingReactionResponses = [:]
        awaitingHumanReaction = false
        applyReactions(responses)
    }

    // MARK: - Hand / match lifecycle

    private func finishHand() {
        let g = engine!
        let result = g.result!
        applyResultToPoints(result)
        emit(.handEnd(result: result))
    }

    /// The engine's own seat.points are the live source of truth during a hand (riichi-
    /// stick deductions already happened there via declareRiichi). Apply win/loss
    /// payments onto that same array, then copy the final values back into `points`.
    private func applyResultToPoints(_ result: HandResult) {
        let g = engine!
        var seatPoints = g.seats.map { $0.points }

        switch result.kind {
        case .tsumo:
            let winnerSeat = result.tsumoSeat!
            let win = result.tsumoWin!
            let isDealerWin = winnerSeat == g.dealerSeat
            for i in 0..<4 {
                if i == winnerSeat { continue }
                let pay: Int
                if isDealerWin {
                    pay = win.payments.fromEachNonDealer ?? 0
                } else {
                    pay = i == g.dealerSeat ? (win.payments.fromDealer ?? 0) : (win.payments.fromEachNonDealer ?? 0)
                }
                seatPoints[i] -= pay
                seatPoints[winnerSeat] += pay
            }
            seatPoints[winnerSeat] += riichiSticksOnTable * 1000
            riichiSticksOnTable = 0
        case .ron:
            for w in result.ronWinners {
                seatPoints[result.ronDiscarder!] -= w.win.total
                seatPoints[w.seat] += w.win.total
            }
            if let first = result.ronWinners.first {
                seatPoints[first.seat] += riichiSticksOnTable * 1000
                riichiSticksOnTable = 0
            }
        case .exhaustive:
            for (i, amount) in result.exhaustivePayments { seatPoints[i] += amount }
            // riichi sticks placed this hand (if any) carry over to the next hand's pot
        }

        // Count any riichi declared this hand toward the carrying pot (sticks already
        // left each declarer's own points via declareRiichi).
        for s in g.seats where s.riichi { riichiSticksOnTable += 1 }

        points = seatPoints
    }

    func advanceToNextHand() {
        let g = engine!
        let dealerWon: Bool
        switch g.result!.kind {
        case .tsumo: dealerWon = g.result!.tsumoSeat == g.dealerSeat
        case .ron: dealerWon = g.result!.ronWinners.contains { $0.seat == g.dealerSeat }
        case .exhaustive: dealerWon = g.result!.dealerTenpai
        }

        if !dealerWon {
            dealerSeat = (dealerSeat + 1) % 4
            handNumber += 1
        }

        if handNumber > 4 {
            matchOver = true
            stop()
            emit(.matchEnd)
            return
        }
        startHand()
    }

    /// Clears the watchdog timer and invalidates any pending scheduled action (via the
    /// generation counter), so the match stops auto-advancing. Call when a match ends
    /// normally or the view is dismissed early.
    func stop() {
        watchdog?.invalidate()
        watchdog = nil
        gen += 1
    }
}
