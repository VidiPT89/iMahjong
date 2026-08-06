import Foundation

/// Simple heuristic bot AI — not a tournament-strength shanten solver, but a pragmatic
/// "keep useful tiles, discard isolated ones, take free wins" player good enough for
/// casual bots. Every function is pure (game state in, decision out).

/// Rough "how useful is this tile to keep" score: pairs/proto-sequences score high,
/// isolated honors/terminals score low. Not a real shanten calculation — a fast
/// approximation good enough for discard ordering.
func tileUsefulness(_ hand: [String], _ tile: String) -> Int {
    let rank = rankOf(tile)
    var score = 0
    let sameCount = hand.filter { $0 == tile }.count
    score += (sameCount - 1) * 4 // pairs/triplets already forming

    if let rank {
        let prefix = String(tile.first!)
        for d in [-2, -1, 1, 2] {
            let r = rank + d
            if r < 1 || r > 9 { continue }
            if hand.contains("\(prefix)\(r)") { score += abs(d) == 1 ? 3 : 1 }
        }
    } else {
        // honors are only useful in pairs/triplets, already counted above
        score -= 1
    }

    if isTerminalOrHonor(tile) && sameCount == 1 { score -= 1 }
    return score
}

func chooseBotDiscard(_ hand: [String], _ melds: [Meld]) -> String {
    var worst = hand[0]
    var worstScore = Int.max
    let uniqueTiles = Array(Set(hand))
    for tile in uniqueTiles {
        var remaining = hand
        if let idx = remaining.firstIndex(of: tile) { remaining.remove(at: idx) }
        let score = tileUsefulness(remaining, tile) + tileUsefulness(hand, tile)
        if score < worstScore { worstScore = score; worst = tile }
    }
    return worst
}

/// Decides a bot's reaction to a discard given the engine-provided options.
func chooseBotReaction(_ game: RiichiEngine, _ seatIndex: Int, _ options: ReactionOptions) -> ReactionResponse {
    if options.ron { return .ron }

    let seat = game.seat(seatIndex)
    let tile = game.lastDiscard!.tile

    if options.pon && isYakuhaiTile(tile, seat.wind, game.roundWind) { return .pon }

    if !options.chi.isEmpty && !seat.melds.isEmpty {
        // Already open — keep leaning into an open hand if it clearly helps.
        let best = options.chi[0]
        return .chi(best[0], best[1])
    }

    return .pass
}

func chooseBotRiichi(_ game: RiichiEngine, _ seatIndex: Int) -> Bool {
    game.canDeclareRiichi(seatIndex)
}

func chooseBotAnkan(_ game: RiichiEngine, _ seatIndex: Int) -> String? {
    game.canAnkan(seatIndex).first
}
