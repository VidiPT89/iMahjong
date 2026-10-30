import SwiftUI

struct TraditionalTableView: View {
    @EnvironmentObject var loc: Localization
    @ObservedObject var match: LocalMatch
    let onExit: () -> Void

    @State private var handResult: HandResult?
    @State private var showMatchEnd = false
    /// Pass-and-play privacy: the human seat whose hand is currently uncovered. With more
    /// than one human on the device, the hand stays hidden behind a handoff screen until the
    /// next player confirms they are the only one looking.
    @State private var revealedSeat: Int?
    /// Table width, so rivers and melds grow on iPad and Mac instead of staying phone-sized.
    @State private var tableWidth: CGFloat = 390

    private var chipScale: CGFloat { min(max(tableWidth / 430, 1), 1.8) }

    private var needsHandoff: Bool {
        match.isHuman.filter { $0 }.count > 1 && revealedSeat != displaySeat
            && handResult == nil && !showMatchEnd
    }

    /// The seat whose hand/actions are shown "as mine" — follows whichever human is
    /// currently up, so pass-and-play with multiple humans works from one device.
    private var displaySeat: Int {
        if let pending = match.pendingHumanSeats.first { return pending }
        let cs = match.engine.currentSeat
        if match.isHuman[cs] { return cs }
        return match.isHuman.firstIndex(of: true) ?? 0
    }

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()

            VStack(spacing: 0) {
                header
                ScrollView { opponentsRow }
                humanPanel
            }
            .background(GeometryReader { geo in
                Color.clear
                    .onAppear { tableWidth = geo.size.width }
                    .onChange(of: geo.size.width) { tableWidth = $0 }
            })

            if match.awaitingHumanReaction, match.pendingHumanSeats.contains(displaySeat) {
                reactionModal
            }

            if needsHandoff {
                handoffCover
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
            if case .matchEnd = match.lastEvent { showMatchEnd = true }
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
            BackButton(action: onExit)

            Spacer()

            VStack(spacing: 1) {
                Text("\(loc.t("roundLabel")) \(loc.t(windLabelKey(match.roundWind))) · \(loc.t("handLabel")) \(match.handNumber)")
                HStack(spacing: 3) {
                    Text("\(loc.t("doraLabel")):")
                    ForEach(Array(match.engine.doraIndicators().enumerated()), id: \.offset) { _, t in MiniTileChip(typeId: t, width: 14) }
                    Text("· \(loc.t("wallLeft")): \(match.engine.liveWall.count)")
                }
            }
            .font(.system(size: 10, weight: .medium))
            .foregroundColor(Theme.textDim)

            Spacer()

            // Fixed width keeps the round info centered whether or not sticks are shown.
            Text(match.riichiSticksOnTable > 0 ? "\(loc.t("riichiSticksLabel")): \(match.riichiSticksOnTable)" : "")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(Theme.accent)
                .multilineTextAlignment(.trailing)
                .frame(width: 90, alignment: .trailing)
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
                OpponentPanel(loc: loc, match: match, seatIndex: seatIndex, isActive: match.engine.currentSeat == seatIndex, chipWidth: 16 * chipScale)
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
                Text(loc.t(windLabelKey(seat.wind)))
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
                                MiniTileChip(typeId: t, width: 22 * chipScale)
                            }
                        }
                    }
                    Spacer()
                }
                .padding(.horizontal, 12)
            }

            if !seat.discards.isEmpty {
                DiscardGrid(tiles: seat.discards, chipWidth: 18 * chipScale)
                    .padding(.horizontal, 12)
            }

            Text(turnHintText())
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(Theme.accent)
                .frame(minHeight: 16)

            handRow(seat: seat, isMyDiscardTurn: isMyDiscardTurn)

            actionButtons(seat: seat)
                .padding(.bottom, 10)
        }
        .padding(.top, 10)
        .background(Theme.bgPanel.ignoresSafeArea(edges: .bottom))
    }

    /// The concealed hand, sized so all 14 tiles fit the width without scrolling. The tile
    /// just drawn is outlined; tiles that can't be discarded right now (e.g. after riichi)
    /// are dimmed on your turn.
    private func handRow(seat: RiichiSeat, isMyDiscardTurn: Bool) -> some View {
        let legal = Set(isMyDiscardTurn ? match.engine.legalDiscards() : [])
        let drawnIndex = isMyDiscardTurn ? match.engine.turnDrawnTile.flatMap { seat.hand.firstIndex(of: $0) } : nil
        return GeometryReader { geo in
            let spacing: CGFloat = 3
            let count = CGFloat(max(seat.hand.count, 14))
            let tileW = min(64, (geo.size.width - 24 - spacing * (count - 1)) / count)
            HStack(spacing: spacing) {
                ForEach(Array(seat.hand.enumerated()), id: \.offset) { index, tile in
                    let enabled = isMyDiscardTurn && legal.contains(tile)
                    Button(action: { match.humanDiscard(tile) }) {
                        TileFaceView(typeId: tile)
                            .padding(2)
                            .frame(width: tileW, height: tileW * 1.36)
                            .background(RoundedRectangle(cornerRadius: 5).fill(Theme.tileFace))
                            .overlay(RoundedRectangle(cornerRadius: 5).stroke(index == drawnIndex ? Theme.ok : Theme.tileEdge, lineWidth: index == drawnIndex ? 2 : 1))
                            .opacity(isMyDiscardTurn && !enabled ? 0.45 : 1)
                    }
                    .buttonStyle(.plain)
                    // Not .disabled: macOS greys out disabled buttons, which made the whole
                    // hand look inactive while waiting. humanDiscard rejects illegal taps.
                    .allowsHitTesting(enabled)
                    .accessibilityLabel(tileAccessibilityName(tile, loc))
                    .accessibilityIdentifier("handTile")
                }
            }
            .frame(maxWidth: .infinity)
        }
        .frame(height: min(64, (tableWidth - 24 - 3 * 13) / 14) * 1.36 + 4)
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
                ForEach(ankanOpts, id: \.self) { type in
                    actionButton(ankanOpts.count > 1 ? "\(loc.t("kanBtn")) \(tileAccessibilityName(type, loc))" : loc.t("kanBtn")) { match.humanAnkan(type) }
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

    // MARK: - Pass-and-play handoff

    private var handoffCover: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()
            VStack(spacing: 16) {
                Image(systemName: "hand.raised.fill")
                    .font(.system(size: 36))
                    .foregroundColor(Theme.accent)
                Text(loc.t("handoffTitle"))
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(Theme.text)
                Text(loc.t("handoffBody").replacingOccurrences(of: "{seat}", with: loc.t(windLabelKey(match.engine.seats[displaySeat].wind))))
                    .font(.system(size: 15))
                    .foregroundColor(Theme.textDim)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                Button(loc.t("handoffReveal")) { revealedSeat = displaySeat }
                    .buttonStyle(PrimaryButtonStyle())
            }
        }
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
                    .accessibilityLabel(tileAccessibilityName(tile, loc))

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
                        Button(action: { match.humanReact(displaySeat, .chi(pair[0], pair[1])) }) {
                            HStack(spacing: 6) {
                                Text(loc.t("chiBtn"))
                                ForEach(pair, id: \.self) { MiniTileChip(typeId: $0, width: 16) }
                            }
                        }
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
    let chipWidth: CGFloat

    var body: some View {
        let seat = match.engine.seats[seatIndex]
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(loc.t(windLabelKey(seat.wind)))
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
            if !seat.melds.isEmpty {
                HStack(spacing: 4) {
                    ForEach(Array(seat.melds.enumerated()), id: \.offset) { _, meld in
                        HStack(spacing: 1) {
                            ForEach(Array(meld.tiles.enumerated()), id: \.offset) { _, t in MiniTileChip(typeId: t, width: chipWidth) }
                        }
                    }
                }
            }
            if !seat.discards.isEmpty {
                DiscardGrid(tiles: seat.discards, chipWidth: chipWidth)
            }
        }
        .padding(8)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 8).fill(Theme.bgPanel).overlay(RoundedRectangle(cornerRadius: 8).stroke(isActive ? Theme.accent : Theme.border, lineWidth: isActive ? 2 : 1)))
    }
}

/// Every discard of a seat in order, wrapping onto new rows instead of scrolling, so the
/// whole river stays readable (it matters for furiten and for reading safe tiles).
private struct DiscardGrid: View {
    let tiles: [String]
    let chipWidth: CGFloat

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: chipWidth, maximum: chipWidth), spacing: 2)], alignment: .leading, spacing: 2) {
            ForEach(Array(tiles.enumerated()), id: \.offset) { _, t in MiniTileChip(typeId: t, width: chipWidth) }
        }
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
                        Text("\(loc.t(windLabelKey(match.engine.seats[entry.seat].wind))) — \(loc.t("hanLabel")) \(entry.win.han) / \(loc.t("fuLabel")) \(entry.win.fu)")
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
                        Text(loc.t(windLabelKey(["wE", "wS", "wW", "wN"][entry.seat])))
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
