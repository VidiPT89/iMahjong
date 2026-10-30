import SwiftUI

/// The table coach: on your turn it suggests the discard with the widest wait; while you
/// wait it lists your winning tiles and warns about furiten or a hand with no yaku.
/// It only uses what that player could see, so it is safe with pass-and-play.
struct CoachStrip: View {
    @EnvironmentObject var loc: Localization
    @AppStorage("ividimahjong-coach") private var enabled = true
    @ObservedObject var match: LocalMatch
    let seatIndex: Int
    let isMyDiscardTurn: Bool

    var body: some View {
        let pt = loc.lang == .pt
        HStack(alignment: .top, spacing: 8) {
            Button(action: { enabled.toggle() }) {
                Image(systemName: enabled ? "graduationcap.fill" : "graduationcap")
                    .foregroundColor(enabled ? Theme.accent : Theme.textDim)
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(pt ? (enabled ? "Esconder treinador" : "Mostrar treinador") : (enabled ? "Hide coach" : "Show coach"))
            if enabled {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(Array(advice.enumerated()), id: \.offset) { _, line in
                        HStack(spacing: 4) {
                            Text(line.text).font(.system(size: 12, weight: line.warning ? .bold : .medium, design: .rounded))
                                .foregroundColor(line.warning ? Theme.danger : Theme.text)
                            ForEach(Array(line.tiles.prefix(9).enumerated()), id: \.offset) { _, t in MiniTileChip(typeId: t, width: 16) }
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Spacer()
            }
        }
        .padding(.horizontal, 12)
        .frame(minHeight: 32)
    }

    private struct Line {
        var text: String
        var tiles: [String] = []
        var warning = false
    }

    private var advice: [Line] {
        let pt = loc.lang == .pt
        let engine = match.engine!
        let seat = engine.seats[seatIndex]
        let visible = engine.seats.flatMap { $0.discards + ($0.seatIndex == seatIndex ? [] : $0.melds.flatMap(\.tiles)) } + engine.doraIndicators()

        if isMyDiscardTurn && !seat.riichi {
            let options = discardOptions(seat.hand, seat.melds, visible: visible)
            let best = bestDiscards(options)
            if let pick = options.first(where: { best.contains($0.tile) }) {
                return [Line(text: pt ? "Larga" : "Drop", tiles: [pick.tile]),
                        Line(text: pt ? "→ esperas (\(pick.acceptance) por ver):" : "→ waits (\(pick.acceptance) unseen):", tiles: pick.waits)]
            }
            let loose = isolatedTiles(seat.hand)
            if !loose.isEmpty {
                return [Line(text: pt ? "Ainda longe de tenpai. Peças soltas a largar primeiro:" : "Not tenpai yet. Loose tiles to drop first:", tiles: loose)]
            }
            return [Line(text: pt ? "Guarda sequências e pares; larga o que não liga a nada." : "Keep runs and pairs; drop what connects to nothing.")]
        }

        guard seat.hand.count % 3 == 1 else { return [] }
        let waits = winningTiles(seat.hand, seat.melds)
        guard !waits.isEmpty else {
            return [Line(text: pt ? "Ainda não estás em tenpai." : "You are not tenpai yet.")]
        }
        var lines = [Line(text: pt ? "Tenpai! Esperas:" : "Tenpai! Waiting on:", tiles: waits)]
        let furiten = furitenTiles(waits: waits, discards: seat.discardHistory)
        if !furiten.isEmpty {
            lines.append(Line(text: pt ? "Furiten: já descartaste" : "Furiten: you discarded", tiles: furiten, warning: true))
        } else if seat.furitenUntilNextDraw {
            lines.append(Line(text: pt ? "Furiten temporário: deixaste passar uma ficha vencedora." : "Temporary furiten: you let a winning tile go.", warning: true))
        }
        let ronHasYaku = waits.contains { engine.evaluateWin(seat, checkWin(seat.hand + [$0], seat.melds), $0, .ron) != nil }
        if !ronHasYaku {
            let closed = seat.melds.allSatisfy(\.concealed)
            lines.append(Line(text: closed
                ? (pt ? "Sem yaku para Ron: declara Riichi ou ganha por Tsumo." : "No yaku for Ron: declare Riichi or win by Tsumo.")
                : (pt ? "Sem yaku: esta mão aberta não pode ganhar." : "No yaku: this open hand cannot win."), warning: true))
        }
        return lines
    }

    /// Tiles with no copy and no neighbour within two ranks — honors first, then terminals.
    private func isolatedTiles(_ hand: [String]) -> [String] {
        let loose = Set(hand).filter { tile in
            guard countInHand(hand, tile) == 1 else { return false }
            guard let rank = rankOf(tile) else { return true }
            return !hand.contains { other in other != tile && other.first == tile.first && abs((rankOf(other) ?? 99) - rank) <= 2 }
        }
        return loose.sorted { a, b in
            let ka = isHonor(a) ? 0 : (isTerminal(a) ? 1 : 2)
            let kb = isHonor(b) ? 0 : (isTerminal(b) ? 1 : 2)
            return ka != kb ? ka < kb : sortTiles([a, b]).first == a
        }
    }
}
