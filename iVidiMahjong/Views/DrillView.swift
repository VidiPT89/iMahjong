import SwiftUI

/// Endless, generated drills: find the waits, choose the best discard, count the points.
/// Every answer is computed by the same engine that scores the Riichi table.
struct DrillView: View {
    @EnvironmentObject var loc: Localization
    @ObservedObject var progress: AcademyProgress
    let kind: DrillKind
    let onBack: () -> Void

    @State private var waitDrill: WaitDrill?
    @State private var discardDrill: DiscardDrill?
    @State private var scoreDrill: ScoreDrill?
    @AppStorage("ividimahjong-wait-level") private var level = 0
    @State private var picked: Set<String> = []
    @State private var discardPick: String?
    @State private var scorePick: Int?
    @State private var checked = false
    @State private var wasRight = false

    private var pt: Bool { loc.lang == .pt }

    private var hasDrill: Bool {
        switch kind {
        case .waits: return waitDrill != nil
        case .discard: return discardDrill != nil
        case .score: return scoreDrill != nil
        }
    }

    var body: some View {
        ZStack {
            BackgroundGlow()
            VStack(spacing: 0) {
                ScreenHeader(title: title, onBack: onBack)
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        let stats = progress.stats(kind)
                        Text(pt ? "Série atual \(stats.streak) · melhor \(stats.bestStreak) · acertos \(stats.correct)/\(stats.answered)"
                                : "Streak \(stats.streak) · best \(stats.bestStreak) · correct \(stats.correct)/\(stats.answered)")
                            .font(.system(size: 12, weight: .semibold, design: .rounded)).foregroundColor(Theme.accent)
                        switch kind {
                        case .waits: waitsBody
                        case .discard: discardBody
                        case .score: scoreBody
                        }
                        if checked {
                            Button(pt ? "Próxima mão" : "Next hand", action: next).buttonStyle(PrimaryButtonStyle())
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .frame(maxWidth: 680).padding(20).frame(maxWidth: .infinity)
                }
            }
        }
        .onAppear { if !hasDrill { next() } }
    }

    private var title: String {
        switch kind {
        case .waits: return pt ? "Que fichas esperas?" : "What are you waiting on?"
        case .discard: return pt ? "Melhor descarte" : "Best discard"
        case .score: return pt ? "Conta os pontos" : "Count the points"
        }
    }

    private func next() {
        var rng = SystemRandomNumberGenerator()
        picked = []
        discardPick = nil
        scorePick = nil
        checked = false
        switch kind {
        case .waits: waitDrill = makeWaitDrill(level: level, using: &rng)
        case .discard: discardDrill = makeDiscardDrill(using: &rng)
        case .score: scoreDrill = makeScoreDrill(using: &rng)
        }
    }

    private func finish(_ right: Bool) {
        wasRight = right
        checked = true
        progress.record(kind, correct: right)
    }

    private var verdict: some View {
        Text(wasRight ? (pt ? "Certo!" : "Correct!") : (pt ? "Ainda não. Vê porquê:" : "Not quite. Here's why:"))
            .font(.system(size: 17, weight: .bold, design: .rounded)).foregroundColor(wasRight ? Theme.ok : Theme.danger)
    }

    private func instruction(_ text: String) -> some View {
        Text(text).font(.system(size: 15, design: .rounded)).foregroundColor(Theme.textDim).fixedSize(horizontal: false, vertical: true)
    }

    // MARK: - Waits

    @ViewBuilder private var waitsBody: some View {
        if let drill = waitDrill {
            Picker("", selection: Binding(get: { level }, set: { level = $0; next() })) {
                Text(pt ? "Básico" : "Basic").tag(0)
                Text(pt ? "Avançado: um só naipe" : "Advanced: one suit").tag(1)
            }
            .pickerStyle(.segmented)
            instruction(pt ? "Esta mão está em tenpai. Toca em todas as fichas que a completam e verifica."
                           : "This hand is tenpai. Tap every tile that completes it, then check.")
            TileRow(tiles: drill.hand, maxTile: 46)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 46), spacing: 6)], spacing: 8) {
                ForEach(drill.choices, id: \.self) { tile in
                    Button(action: { if !checked { picked.formSymmetricDifference([tile]) } }) {
                        StudyTile(typeId: tile, width: 42, outline: waitOutline(tile, drill), dimmed: checked && !drill.waits.contains(tile) && !picked.contains(tile))
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(picked.contains(tile) ? .isSelected : [])
                    .accessibilityIdentifier("wait-choice")
                }
            }
            if !checked {
                Button(pt ? "Verificar" : "Check") { finish(picked == Set(drill.waits)) }
                    .accessibilityIdentifier("check")
                    .buttonStyle(PrimaryButtonStyle()).frame(maxWidth: .infinity)
                    .disabled(picked.isEmpty).opacity(picked.isEmpty ? 0.5 : 1)
            } else {
                AcademyCard {
                    verdict
                    Text(pt ? "Esperas (\(acceptance(drill.waits, visible: drill.hand)) fichas por ver):" : "Waits (\(acceptance(drill.waits, visible: drill.hand)) tiles unseen):")
                        .font(.system(size: 13, weight: .semibold, design: .rounded)).foregroundColor(Theme.text)
                    HStack(spacing: 4) { ForEach(drill.waits, id: \.self) { StudyTile(typeId: $0, width: 34) } }
                    instruction(pt ? "Verde: espera certa. Vermelho: escolhida mas não completa a mão. Dourado: espera que faltou."
                                   : "Green: correct wait. Red: picked but doesn't complete the hand. Gold: a wait you missed.")
                }
            }
        }
    }

    private func waitOutline(_ tile: String, _ drill: WaitDrill) -> Color? {
        let isWait = drill.waits.contains(tile)
        let isPicked = picked.contains(tile)
        if !checked { return isPicked ? Theme.accent : nil }
        if isWait { return isPicked ? Theme.ok : Theme.accent }
        return isPicked ? Theme.danger : nil
    }

    // MARK: - Discard

    @ViewBuilder private var discardBody: some View {
        if let drill = discardDrill {
            instruction(pt ? "Compraste a 14.ª ficha. Que descarte te deixa em tenpai com mais fichas vencedoras?"
                           : "You just drew your 14th tile. Which discard leaves you tenpai with the most winning tiles?")
            TileRow(tiles: drill.hand, maxTile: 46, outline: { i in
                guard checked else { return nil }
                let tile = drill.hand[i]
                if drill.best.contains(tile) { return Theme.ok }
                return tile == discardPick ? Theme.danger : nil
            }, onTap: { i in
                guard !checked else { return }
                discardPick = drill.hand[i]
                finish(drill.best.contains(drill.hand[i]))
            })
            if checked {
                AcademyCard {
                    verdict
                    ForEach(drill.options.filter { $0.acceptance > 0 }.sorted { $0.acceptance > $1.acceptance }, id: \.tile) { option in
                        HStack(spacing: 6) {
                            Text(pt ? "Larga" : "Drop").font(.system(size: 12, design: .rounded)).foregroundColor(Theme.textDim)
                            StudyTile(typeId: option.tile, width: 28, outline: drill.best.contains(option.tile) ? Theme.ok : nil)
                            Image(systemName: "arrow.right").font(.system(size: 11)).foregroundColor(Theme.textDim)
                            ForEach(option.waits, id: \.self) { StudyTile(typeId: $0, width: 24) }
                            Spacer()
                            Text(pt ? "\(option.acceptance) fichas" : "\(option.acceptance) tiles")
                                .font(.system(size: 12, weight: .semibold, design: .rounded)).foregroundColor(Theme.text)
                        }
                    }
                    if let pick = discardPick, !(drill.options.first { $0.tile == pick }.map { $0.acceptance > 0 } ?? false) {
                        instruction(pt ? "Largar \(tileAccessibilityName(pick, loc)) não te deixa em tenpai."
                                       : "Dropping \(tileAccessibilityName(pick, loc)) doesn't leave you tenpai.")
                    }
                    instruction(pt ? "Conta as fichas que ainda podem sair: uma espera de dois lados quase sempre vale mais do que uma de ponta ou do meio."
                                   : "Count the tiles that can still come: a two-sided wait almost always beats an edge or middle wait.")
                }
            }
        }
    }

    // MARK: - Score

    @ViewBuilder private var scoreBody: some View {
        if let drill = scoreDrill {
            let chips = [
                drill.winType == .ron ? "Ron" : "Tsumo",
                drill.isDealer ? (pt ? "És o dealer (Este)" : "You are dealer (East)") : (pt ? "Não és dealer · vento \(loc.t(windLabelKey(drill.seatWind)))" : "Not dealer · \(loc.t(windLabelKey(drill.seatWind))) seat"),
                pt ? "Ronda Este" : "East round",
            ] + (drill.riichi ? ["Riichi"] : []) + (drill.doraCount > 0 ? ["Dora × \(drill.doraCount)"] : [])
            instruction(pt ? "Ganhaste com a ficha marcada. Quantos pontos recebes ao todo?" : "You won on the marked tile. How many points do you collect in total?")
            HStack(spacing: 6) {
                ForEach(chips, id: \.self) { chip in
                    Text(chip).font(.system(size: 11, weight: .semibold, design: .rounded)).foregroundColor(Theme.text)
                        .padding(.horizontal, 9).padding(.vertical, 5).background(Capsule().fill(Theme.bgPanel2))
                }
            }
            let winIndex = drill.hand.lastIndex(of: drill.winTile)
            TileRow(tiles: drill.hand, maxTile: 46, outline: { $0 == winIndex ? Theme.accent : nil })
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(drill.choices, id: \.self) { value in
                    Button(action: {
                        guard !checked else { return }
                        scorePick = value
                        finish(value == drill.payment.total)
                    }) {
                        Text("\(value)").font(.system(size: 17, weight: .bold, design: .rounded))
                            .foregroundColor(Theme.text).frame(maxWidth: .infinity).padding(.vertical, 12)
                            .background(RoundedRectangle(cornerRadius: 10).fill(Theme.bgPanel2))
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(scoreOutline(value, drill) ?? .clear, lineWidth: 2.5))
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("score-choice")
                }
            }
            if checked { scoreExplanation(drill) }
        }
    }

    private func scoreOutline(_ value: Int, _ drill: ScoreDrill) -> Color? {
        guard checked else { return nil }
        if value == drill.payment.total { return Theme.ok }
        return value == scorePick ? Theme.danger : nil
    }

    private func scoreExplanation(_ drill: ScoreDrill) -> some View {
        let r = drill.evaluation.result
        let base = drill.payment.base
        let p = drill.payment.payments
        let payment: String
        if drill.winType == .ron {
            payment = pt ? "Ron: quem descartou paga tudo, base × \(drill.isDealer ? 6 : 4) = \(drill.payment.total)."
                         : "Ron: the discarder pays it all, base × \(drill.isDealer ? 6 : 4) = \(drill.payment.total)."
        } else if drill.isDealer {
            payment = pt ? "Tsumo do dealer: cada um paga \(p.fromEachNonDealer ?? 0) (base × 2)." : "Dealer tsumo: everyone pays \(p.fromEachNonDealer ?? 0) (base × 2)."
        } else {
            payment = pt ? "Tsumo: o dealer paga \(p.fromDealer ?? 0) e os outros \(p.fromEachNonDealer ?? 0) cada."
                         : "Tsumo: the dealer pays \(p.fromDealer ?? 0), the others \(p.fromEachNonDealer ?? 0) each."
        }
        return AcademyCard {
            verdict
            SectionLabel(text: "Yaku")
            YakuExplanationList(yakuList: r.yakuList, lang: loc.lang)
            if drill.doraCount > 0 {
                Text("Dora × \(drill.doraCount) · +\(drill.doraCount) han").font(.system(size: 13, weight: .semibold, design: .rounded)).foregroundColor(Theme.text)
            }
            Text("= \(r.han) han").font(.system(size: 14, weight: .bold, design: .rounded)).foregroundColor(Theme.accent)
            SectionLabel(text: "Fu")
            ForEach(Array(drill.fuParts.enumerated()), id: \.offset) { _, part in
                Text(fuPartLabel(part, loc)).font(.system(size: 13, design: .rounded)).foregroundColor(Theme.textDim)
            }
            Text(pt ? "= \(r.fu) fu (arredondado à dezena)" : "= \(r.fu) fu (rounded up to 10)")
                .font(.system(size: 14, weight: .bold, design: .rounded)).foregroundColor(Theme.accent)
            SectionLabel(text: pt ? "Pontos" : "Points")
            Text(limitName(han: r.han, base: base) ?? "\(r.fu) × 2^(\(r.han) + 2) = \(base)")
                .font(.system(size: 13, design: .rounded)).foregroundColor(Theme.text)
            instruction(payment)
        }
    }

    private func limitName(han: Int, base: Int) -> String? {
        let name: String
        switch han {
        case 13...: name = "Yakuman"
        case 11...12: name = "Sanbaiman"
        case 8...10: name = "Baiman"
        case 6...7: name = "Haneman"
        default:
            guard han >= 5 || base == 2000 else { return nil }
            name = "Mangan"
        }
        return pt ? "\(han) han: \(name), base fixa \(base)" : "\(han) han: \(name), fixed base \(base)"
    }
}
