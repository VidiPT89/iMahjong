import SwiftUI

private let windLabelKeys = ["wE": "windE", "wS": "windS", "wW": "windW", "wN": "windN"]

struct TraditionalTableView: View {
    @EnvironmentObject var loc: Localization
    @ObservedObject var match: LocalMatch
    let onExit: () -> Void

    @State private var handResult: HandResult?
    @State private var showMatchEnd = false

    /// The seat whose hand/actions are shown "as mine" — follows whichever human is
    /// currently up, so pass-and-play with multiple humans works from one device.
    private var displaySeat: Int {
        let cs = match.engine.currentSeat
        if match.isHuman[cs] { return cs }
        return match.isHuman.firstIndex(of: true) ?? 0
    }

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()

            VStack(spacing: 0) {
                header
                opponentsRow
                Spacer(minLength: 4).frame(maxHeight: 40)
                humanPanel
            }

            if match.awaitingHumanReaction, match.pendingHumanSeats.contains(displaySeat) {
                reactionModal
            }

            if let handResult {
                HandResultModal(loc: loc, match: match, result: handResult, displaySeat: displaySeat, onNext: {
                    self.handResult = nil
                    if match.matchOver {
                        showMatchEnd = true
                    } else {
                        match.advanceToNextHand()
                    }
                })
            }

            if showMatchEnd {
                MatchEndModal(loc: loc, points: match.points, onDone: onExit)
            }
        }
        .onChange(of: match.lastEvent.map(eventKey)) { _ in
            if case .handEnd(let result) = match.lastEvent { handResult = result }
        }
    }

    private func eventKey(_ e: MatchEvent) -> Int {
        switch e {
        case .handStart: return 0
        case .drawn: return 1
        case .awaitHumanDiscard: return 2
        case .awaitHumanReaction: return 3
        case .discarded: return 4
        case .called: return 5
        case .riichi: return 6
        case .kan: return 7
        case .handEnd: return 8
        case .matchEnd: return 9
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 6) {
            Button(action: onExit) {
                Image(systemName: "chevron.left")
                    .foregroundColor(Theme.text)
                    .frame(width: 30, height: 30)
                    .background(Circle().fill(Theme.bgPanel2))
            }
            .buttonStyle(.plain)

            Spacer()

            VStack(spacing: 1) {
                Text("\(loc.t("roundLabel")) \(loc.t(windLabelKeys[match.roundWind] ?? "")) · \(loc.t("handLabel")) \(match.handNumber)")
                Text("\(loc.t("doraLabel")): \(match.engine.doraIndicators().first ?? "") · \(loc.t("wallLeft")): \(match.engine.liveWall.count)")
            }
            .font(.system(size: 10, weight: .medium))
            .foregroundColor(Theme.textDim)

            Spacer()

            Text("\(loc.t("riichiSticksLabel")): \(match.riichiSticksOnTable)")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(Theme.accent)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Theme.bgPanel.opacity(0.6))
    }

    // MARK: - Opponents

    private var opponentsRow: some View {
        let order = [1, 2, 3].map { (displaySeat + $0) % 4 }
        return VStack(spacing: 6) {
            ForEach(order, id: \.self) { seatIndex in
                OpponentPanel(loc: loc, match: match, seatIndex: seatIndex, isActive: match.engine.currentSeat == seatIndex)
            }
        }
        .padding(.horizontal, 10)
        .padding(.top, 8)
    }

    // MARK: - Human panel

    private var humanPanel: some View {
        let seat = match.engine.seats[displaySeat]
        let isMyDiscardTurn = match.engine.currentSeat == displaySeat && match.engine.phase == .discard && match.isHuman[displaySeat]

        return VStack(spacing: 8) {
            HStack(spacing: 8) {
                Text(loc.t(windLabelKeys[seat.wind] ?? ""))
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(Theme.accent)
                Text("\(loc.t("pointsLabel")): \(seat.points)")
                    .font(.system(size: 12))
                    .foregroundColor(Theme.textDim)
                if seat.riichi {
                    Text(loc.t("riichiBtn"))
                        .font(.system(size: 10, weight: .bold))
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(Capsule().fill(Theme.accent))
                        .foregroundColor(Theme.bg)
                }
                Spacer()
            }
            .padding(.horizontal, 12)

            if !seat.melds.isEmpty {
                HStack(spacing: 4) {
                    ForEach(Array(seat.melds.enumerated()), id: \.offset) { _, meld in
                        HStack(spacing: 1) {
                            ForEach(Array(meld.tiles.enumerated()), id: \.offset) { _, t in
                                MiniTileChip(typeId: t)
                            }
                        }
                    }
                    Spacer()
                }
                .padding(.horizontal, 12)
            }

            if !seat.discards.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 2) {
                        ForEach(Array(seat.discards.enumerated()), id: \.offset) { _, d in
                            MiniTileChip(typeId: d.tile)
                        }
                    }
                    .padding(.horizontal, 12)
                }
                .frame(height: 40)
            }

            Text(turnHintText())
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(Theme.accent)
                .frame(minHeight: 16)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    ForEach(Array(seat.hand.enumerated()), id: \.offset) { _, tile in
                        Button(action: { if isMyDiscardTurn { match.humanDiscard(tile) } }) {
                            TileFaceView(typeId: tile)
                                .frame(width: 32, height: 44)
                                .background(RoundedRectangle(cornerRadius: 5).fill(Theme.tileFace))
                                .overlay(RoundedRectangle(cornerRadius: 5).stroke(Theme.tileEdge, lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                        .disabled(!isMyDiscardTurn)
                    }
                }
                .padding(.horizontal, 12)
            }

            actionButtons(seat: seat)
                .padding(.bottom, 10)
        }
        .background(Theme.bgPanel)
    }

    private func turnHintText() -> String {
        if match.engine.currentSeat == displaySeat && match.isHuman[displaySeat] {
            return match.engine.phase == .discard ? loc.t("yourTurnDiscard") : ""
        }
        return loc.t("waitingOthers")
    }

    @ViewBuilder
    private func actionButtons(seat: RiichiSeat) -> some View {
        let isMyTurn = match.engine.currentSeat == displaySeat && match.isHuman[displaySeat]
        HStack(spacing: 8) {
            if isMyTurn && match.engine.canDeclareTsumo() {
                actionButton(loc.t("tsumoBtn")) { match.humanDeclareTsumo() }
            }
            if isMyTurn && match.engine.canDeclareRiichi(displaySeat) {
                actionButton(loc.t("riichiBtn")) { match.humanDeclareRiichi() }
            }
            if isMyTurn {
                let ankanOpts = match.engine.canAnkan(displaySeat)
                if let first = ankanOpts.first {
                    actionButton(loc.t("kanBtn")) { match.humanAnkan(first) }
                }
            }
        }
        .padding(.horizontal, 12)
    }

    private func actionButton(_ label: String, action: @escaping () -> Void) -> some View {
        Button(label, action: action)
            .font(.system(size: 13, weight: .bold))
            .foregroundColor(Theme.bg)
            .padding(.horizontal, 16).padding(.vertical, 8)
            .background(Capsule().fill(Theme.accent))
    }

    // MARK: - Reaction modal

    private var reactionModal: some View {
        let opts = match.engine.getReactionSummary()[displaySeat] ?? ReactionOptions()
        let tile = match.engine.lastDiscard?.tile ?? ""
        return ZStack {
            Color.black.opacity(0.55).ignoresSafeArea()
            VStack(spacing: 14) {
                TileFaceView(typeId: tile)
                    .frame(width: 44, height: 60)
                    .background(RoundedRectangle(cornerRadius: 6).fill(Theme.tileFace))

                VStack(spacing: 10) {
                    if opts.ron {
                        Button(loc.t("ronBtn")) { match.humanReact(displaySeat, .ron) }.buttonStyle(PrimaryButtonStyle())
                    }
                    if opts.kan {
                        Button(loc.t("kanBtn")) { match.humanReact(displaySeat, .kan) }.buttonStyle(SecondaryButtonStyle())
                    }
                    if opts.pon {
                        Button(loc.t("ponBtn")) { match.humanReact(displaySeat, .pon) }.buttonStyle(SecondaryButtonStyle())
                    }
                    ForEach(Array(opts.chi.enumerated()), id: \.offset) { _, pair in
                        Button("\(loc.t("chiBtn")) \(pair[0])+\(pair[1])") { match.humanReact(displaySeat, .chi(pair[0], pair[1])) }
                            .buttonStyle(SecondaryButtonStyle())
                    }
                    Button(loc.t("passBtn")) { match.humanReact(displaySeat, .pass) }.buttonStyle(GhostButtonStyle())
                }
            }
            .padding(24)
            .background(RoundedRectangle(cornerRadius: 16).fill(Theme.bgPanel).overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.borderStrong, lineWidth: 1)))
            .padding(32)
        }
    }
}

private struct OpponentPanel: View {
    let loc: Localization
    @ObservedObject var match: LocalMatch
    let seatIndex: Int
    let isActive: Bool

    var body: some View {
        let seat = match.engine.seats[seatIndex]
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(loc.t(windLabelKeys[seat.wind] ?? ""))
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(Theme.accent)
                if seat.riichi {
                    Circle().fill(Theme.accent).frame(width: 6, height: 6)
                }
                Spacer()
                Text("\(seat.points)")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(Theme.text)
            }
            if !seat.discards.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 2) {
                        ForEach(Array(seat.discards.suffix(8).enumerated()), id: \.offset) { _, d in
                            MiniTileChip(typeId: d.tile)
                        }
                    }
                }
            }
        }
        .padding(8)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 8).fill(Theme.bgPanel).overlay(RoundedRectangle(cornerRadius: 8).stroke(isActive ? Theme.accent : Theme.border, lineWidth: isActive ? 2 : 1)))
    }
}

private struct MiniTileChip: View {
    let typeId: String
    var body: some View {
        TileFaceView(typeId: typeId)
            .frame(width: 22, height: 30)
            .background(RoundedRectangle(cornerRadius: 3).fill(Theme.tileFace))
            .overlay(RoundedRectangle(cornerRadius: 3).stroke(Theme.tileEdge, lineWidth: 0.5))
    }
}

private struct HandResultModal: View {
    let loc: Localization
    @ObservedObject var match: LocalMatch
    let result: HandResult
    let displaySeat: Int
    let onNext: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.6).ignoresSafeArea()
            VStack(spacing: 12) {
                Text(title)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(Theme.text)

                ForEach(winEntries, id: \.seat) { entry in
                    VStack(spacing: 4) {
                        Text("\(loc.t(windLabelKeys[match.engine.seats[entry.seat].wind] ?? "")) — \(loc.t("hanLabel")) \(entry.win.han) / \(loc.t("fuLabel")) \(entry.win.fu)")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(Theme.accent)
                        Text(entry.win.yakuList.map { "\($0.name) (\($0.han))" }.joined(separator: ", "))
                            .font(.system(size: 11))
                            .foregroundColor(Theme.textDim)
                            .multilineTextAlignment(.center)
                        Text("\(loc.t("totalPoints")): \(entry.win.total)")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(Theme.text)
                    }
                    .padding(.top, 4)
                }

                if case .exhaustive = result.kind {
                    Text("\(loc.t("tenpaiLabel")): \(result.tenpaiSeats.count)")
                        .font(.system(size: 13))
                        .foregroundColor(Theme.textDim)
                }

                Button(loc.t("nextHand"), action: onNext)
                    .buttonStyle(PrimaryButtonStyle())
                    .padding(.top, 8)
            }
            .padding(26)
            .frame(maxWidth: 360)
            .background(RoundedRectangle(cornerRadius: 18).fill(Theme.bgPanel).overlay(RoundedRectangle(cornerRadius: 18).stroke(Theme.borderStrong, lineWidth: 1)))
            .padding(24)
        }
    }

    private var title: String {
        switch result.kind {
        case .tsumo: return loc.t("tsumoWinTitle")
        case .ron: return loc.t("ronWinTitle")
        case .exhaustive: return loc.t("exhaustiveDrawTitle")
        }
    }

    private var winEntries: [(seat: Int, win: EvaluatedWin)] {
        switch result.kind {
        case .tsumo: return [(result.tsumoSeat!, result.tsumoWin!)]
        case .ron: return result.ronWinners
        case .exhaustive: return []
        }
    }
}

private struct MatchEndModal: View {
    let loc: Localization
    let points: [Int]
    let onDone: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.6).ignoresSafeArea()
            VStack(spacing: 12) {
                Text(loc.t("matchEndTitle")).font(.system(size: 22, weight: .bold)).foregroundColor(Theme.text)
                Text(loc.t("finalStandings")).font(.system(size: 13)).foregroundColor(Theme.textDim)

                ForEach(rankedSeats, id: \.seat) { entry in
                    HStack {
                        Text(loc.t(windLabelKeys[["wE", "wS", "wW", "wN"][entry.seat]] ?? ""))
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(Theme.text)
                        Spacer()
                        Text("\(entry.points)")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(Theme.accent)
                    }
                    .padding(.horizontal, 20)
                }

                Button(loc.t("backToMenu"), action: onDone)
                    .buttonStyle(PrimaryButtonStyle())
                    .padding(.top, 8)
            }
            .padding(26)
            .frame(maxWidth: 340)
            .background(RoundedRectangle(cornerRadius: 18).fill(Theme.bgPanel).overlay(RoundedRectangle(cornerRadius: 18).stroke(Theme.borderStrong, lineWidth: 1)))
        }
    }

    private var rankedSeats: [(seat: Int, points: Int)] {
        points.enumerated().map { (seat: $0.offset, points: $0.element) }.sorted { $0.points > $1.points }
    }
}
