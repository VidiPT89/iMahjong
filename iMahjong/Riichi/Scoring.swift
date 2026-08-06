import Foundation

/// Han/fu → points conversion and ron/tsumo payment split, standard table.

func baseScoreFromHanFu(_ han: Int, _ fu: Int, _ yakuman: Bool, _ yakumanCount: Int) -> Int {
    if yakuman { return 8000 * yakumanCount }
    if han >= 13 { return 8000 } // kazoe yakuman (counted yakuman by han)
    if han >= 11 { return 6000 } // sanbaiman
    if han >= 8 { return 4000 } // baiman
    if han >= 6 { return 3000 } // haneman
    if han >= 5 { return 2000 } // mangan
    var base = fu * Int(pow(2.0, Double(2 + han)))
    if base > 2000 { base = 2000 } // kiriage mangan
    return base
}

private func roundUpTo100(_ n: Int) -> Int {
    Int(ceil(Double(n) / 100)) * 100
}

struct ScorePayments {
    var fromDiscarder: Int?
    var fromDealer: Int?
    var fromEachNonDealer: Int?
}

struct ScoreResult {
    var base: Int
    var total: Int
    var payments: ScorePayments
}

/// result: han/fu/yakuman from bestYakuResult(). Returns who pays what.
func scorePoints(_ result: YakuResult, isDealer: Bool, winType: WinType) -> ScoreResult {
    let base = baseScoreFromHanFu(result.han, result.fu, result.yakuman, result.yakumanCount)

    if winType == .ron {
        let payment = roundUpTo100(base * (isDealer ? 6 : 4))
        return ScoreResult(base: base, total: payment, payments: ScorePayments(fromDiscarder: payment))
    }

    if isDealer {
        let each = roundUpTo100(base * 2)
        return ScoreResult(base: base, total: each * 3, payments: ScorePayments(fromEachNonDealer: each))
    }

    let fromDealer = roundUpTo100(base * 2)
    let fromNonDealer = roundUpTo100(base * 1)
    return ScoreResult(
        base: base,
        total: fromDealer + fromNonDealer * 2,
        payments: ScorePayments(fromDealer: fromDealer, fromEachNonDealer: fromNonDealer)
    )
}
