import SwiftUI

private let windLabelKeysOnline = ["wE": "windE", "wS": "windS", "wW": "windW", "wN": "windN"]

/// Renders the traditional 4-player Riichi table for online play. Unlike TraditionalTableView
/// (which reads a local RiichiEngine object graph), this reads the loosely-typed `state`
/// dictionary the server pushes down after every change -- the server is the sole source of
/// truth, so this view never runs any game rule itself, only sends the player's intent
/// (discard/react/riichi/tsumo/ankan/nextHand) and renders whatever comes back.
struct OnlineTableView: View {
    @EnvironmentObject var loc: Localization
    @ObservedObject var client: OnlineClient
    let onExit: () -> Void

    private var state: [String: Any] { client.state ?? [:] }
    private var mySeat: Int { client.seat ?? 0 }

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()

            VStack(spacing: 0) {
                header
                opponentsRow
                Spacer(minLength: 4).frame(maxHeight: 40)
                humanPanel
            }
            .frame(maxHeight: .infinity, alignment: .top)

            if client.awaitReactionOpts != nil {
                reactionModal
            }

            if state.str("phase") == "ended", let result = state.dict("result") {
                handResultModal(result)
            }

            if state.bool("matchOver") == true {
                matchEndModal((state.array("points") as? [Int]) ?? [0, 0, 0, 0])
            }

            if client.connectionLost {
                connectionLostOverlay
            }
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

            VStack(alignment: .leading, spacing: 2) {
                Text("\(loc.t("roundLabel")) \(loc.t(windLabelKeysOnline[state.str("roundWind") ?? "wE"] ?? "windE")) · \(loc.t("handLabel")) \(state.int("handNumber") ?? 1)")
                Text("\(loc.t("doraLabel")): \(state.stringArray("dora").map { TILE_TYPES_BY_ID[$0]?.id ?? $0 }.joined(separator: " "))")
            }
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(Theme.textDim)

            Spacer()

            Text("\(loc.t("wallLeft")): \(state.int("wallCount") ?? 0)")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(Theme.textDim)

            let sticks = state.int("riichiSticksOnTable") ?? 0
            if sticks > 0 {
                Text("\(loc.t("riichiSticksLabel")): \(sticks)")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(Theme.accent)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    // MARK: - Opponents

    private var opponentsRow: some View {
        let seats = state.dictArray("seats")
        let dealerSeat = state.int("dealerSeat") ?? 0
        let currentSeat = state.int("currentSeat") ?? 0

        return HStack(spacing: 6) {
            ForEach([1, 2, 3], id: \.self) { offset in
                let seatIndex = (mySeat + offset) % 4
                if seatIndex < seats.count {
                    opponentPanel(seats[seatIndex], seatIndex: seatIndex, isDealer: seatIndex == dealerSeat, isActive: seatIndex == currentSeat)
                }
            }
        }
        .padding(.horizontal, 8)
    }

    private func opponentPanel(_ seat: [String: Any], seatIndex: Int, isDealer: Bool, isActive: Bool) -> some View {
        VStack(spacing: 4) {
            HStack {
                Text(loc.t(windLabelKeysOnline[seat.str("wind") ?? "wE"] ?? "windE") + (isDealer ? " 🀄" : ""))
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(Theme.text)
                Spacer()
                Text("\(seat.int("points") ?? 0)")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(Theme.textDim)
            }

            HStack {
                let isBot = seat.bool("isBot") ?? true
                let isConnected = seat.bool("isConnected") ?? false
                let name = isBot ? loc.t("bot") : (isConnected ? (seat.str("name") ?? "") : "\(seat.str("name") ?? "") (\(loc.t("playerWaiting")))")
                Text(name + (seat.bool("riichi") == true ? " · \(loc.t("riichiBtn"))" : ""))
                    .font(.system(size: 9))
                    .foregroundColor(Theme.textFaint)
                    .lineLimit(1)
                Spacer()
                Text("\(seat.int("handCount") ?? 0) 🀫")
                    .font(.system(size: 9))
                    .foregroundColor(Theme.textFaint)
            }

            let melds = seat.dictArray("melds")
            if !melds.isEmpty {
                HStack(spacing: 2) {
                    ForEach(melds.indices, id: \.self) { i in
                        ForEach(melds[i].stringArray("tiles"), id: \.self) { t in MiniTileChipOnline(typeId: t) }
                    }
                }
            }

            let discards = seat.dictArray("discards")
            if !discards.isEmpty {
                let cols = Array(repeating: GridItem(.fixed(14), spacing: 2), count: 6)
                LazyVGrid(columns: cols, spacing: 2) {
                    ForEach(discards.indices, id: \.self) { i in
                        MiniTileChipOnline(typeId: discards[i].str("tile") ?? "")
                    }
                }
            }
        }
        .padding(6)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 8).fill(Theme.bgPanel).overlay(RoundedRectangle(cornerRadius: 8).stroke(isActive ? Theme.accent : Theme.border, lineWidth: isActive ? 2 : 1)))
    }

    // MARK: - Human panel

    private var humanPanel: some View {
        let you = state.dict("you") ?? [:]
        let seats = state.dictArray("seats")
        let mySeatInfo = mySeat < seats.count ? seats[mySeat] : [:]
        let isMyDiscardTurn = state.int("currentSeat") == mySeat && state.str("phase") == "discard"
        let drawnTile = state.str("turnDrawnTile")

        return VStack(spacing: 6) {
            HStack {
                Text(loc.t(windLabelKeysOnline[mySeatInfo.str("wind") ?? "wE"] ?? "windE") + (mySeat == state.int("dealerSeat") ? " 🀄" : ""))
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(Theme.text)
                Spacer()
                Text("\(loc.t("pointsLabel")): \(you.int("points") ?? 0)")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Theme.textDim)
                if you.bool("riichi") == true {
                    Text(loc.t("riichiBtn"))
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(Theme.bg)
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(Capsule().fill(Theme.accent))
                }
            }

            let melds = you.dictArray("melds")
            if !melds.isEmpty {
                HStack(spacing: 4) {
                    ForEach(melds.indices, id: \.self) { i in
                        ForEach(melds[i].stringArray("tiles"), id: \.self) { t in MiniTileChipOnline(typeId: t) }
                    }
                }
            }

            let discards = you.dictArray("discards")
            if !discards.isEmpty {
                let cols = Array(repeating: GridItem(.fixed(18), spacing: 3), count: 9)
                LazyVGrid(columns: cols, spacing: 3) {
                    ForEach(discards.indices, id: \.self) { i in
                        MiniTileChipOnline(typeId: discards[i].str("tile") ?? "")
                    }
                }
            }

            Text(isMyDiscardTurn ? loc.t("yourTurnDiscard") : (state.str("phase") == "reaction" ? loc.t("waitingOthers") : ""))
                .font(.system(size: 11))
                .foregroundColor(Theme.textFaint)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 3) {
                    ForEach(you.stringArray("hand").sorted(), id: \.self) { tile in
                        Button(action: { if isMyDiscardTurn { client.discard(tile) } }) {
                            TileFaceView(typeId: tile)
                                .frame(width: 34, height: 46)
                                .background(RoundedRectangle(cornerRadius: 4).fill(Theme.tileFace))
                                .overlay(RoundedRectangle(cornerRadius: 4).stroke(tile == drawnTile ? Theme.ok : Theme.tileEdge, lineWidth: tile == drawnTile ? 2 : 1))
                        }
                        .buttonStyle(.plain)
                        .disabled(!isMyDiscardTurn)
                    }
                }
                .padding(.vertical, 4)
            }

            if isMyDiscardTurn {
                HStack(spacing: 8) {
                    if state.bool("canTsumo") == true {
                        Button(loc.t("tsumoBtn"), action: { client.declareTsumo() }).buttonStyle(PrimaryButtonStyle())
                    }
                    if state.bool("canRiichi") == true {
                        Button(loc.t("riichiBtn"), action: { client.declareRiichi() }).buttonStyle(SecondaryButtonStyle())
                    }
                    ForEach(state.stringArray("ankanOptions"), id: \.self) { type in
                        Button("\(loc.t("kanBtn")) \(TILE_TYPES_BY_ID[type]?.id ?? type)", action: { client.ankan(tileType: type) })
                            .buttonStyle(GhostButtonStyle())
                    }
                }
            }
        }
        .padding(10)
        .background(Theme.bgPanel.opacity(0.6))
    }

    // MARK: - Reaction modal

    private var reactionModal: some View {
        let opts = client.awaitReactionOpts ?? [:]
        let lastDiscard = state.dict("lastDiscard")
        let tile = lastDiscard?.str("tile") ?? ""

        return ZStack {
            Color.black.opacity(0.5).ignoresSafeArea()
            VStack(spacing: 14) {
                HStack {
                    Text(TILE_TYPES_BY_ID[tile]?.id ?? tile).foregroundColor(Theme.text)
                    TileFaceView(typeId: tile).frame(width: 34, height: 46)
                }
                VStack(spacing: 8) {
                    if opts.bool("ron") == true {
                        Button(loc.t("ronBtn"), action: { client.reactRon() }).buttonStyle(PrimaryButtonStyle())
                    }
                    if opts.bool("kan") == true {
                        Button(loc.t("kanBtn"), action: { client.reactKan() }).buttonStyle(GhostButtonStyle())
                    }
                    if opts.bool("pon") == true {
                        Button(loc.t("ponBtn"), action: { client.reactPon() }).buttonStyle(GhostButtonStyle())
                    }
                    ForEach((opts.array("chi") as? [[String]]) ?? [], id: \.self) { pair in
                        Button("\(loc.t("chiBtn")) \(pair.map { TILE_TYPES_BY_ID[$0]?.id ?? $0 }.joined(separator: "+"))", action: { client.reactChi(pair) })
                            .buttonStyle(GhostButtonStyle())
                    }
                    Button(loc.t("passBtn"), action: { client.reactPass() }).buttonStyle(GhostButtonStyle())
                }
            }
            .padding(20)
            .background(RoundedRectangle(cornerRadius: 14).fill(Theme.bgPanel))
            .padding(40)
        }
    }

    // MARK: - Hand result modal

    private func handResultModal(_ result: [String: Any]) -> some View {
        let seats = state.dictArray("seats")
        let type = result.str("type") ?? ""

        return ZStack {
            Color.black.opacity(0.5).ignoresSafeArea()
            VStack(spacing: 12) {
                Text(type == "exhaustive" ? loc.t("exhaustiveDrawTitle") : (type == "tsumo" ? loc.t("tsumoWinTitle") : loc.t("ronWinTitle")))
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(Theme.text)

                ScrollView {
                    if type == "exhaustive" {
                        let tenpaiSeats = (result.array("tenpaiSeats") as? [Int]) ?? []
                        VStack(spacing: 4) {
                            ForEach(0..<seats.count, id: \.self) { i in
                                HStack {
                                    Text(loc.t(windLabelKeysOnline[seats[i].str("wind") ?? "wE"] ?? "windE"))
                                    Spacer()
                                    Text(tenpaiSeats.contains(i) ? loc.t("tenpaiLabel") : loc.t("notenLabel"))
                                }
                                .font(.system(size: 13))
                                .foregroundColor(Theme.textDim)
                            }
                        }
                    } else {
                        let winners: [[String: Any]] = type == "tsumo" ? [result] : result.dictArray("winners")
                        VStack(alignment: .leading, spacing: 10) {
                            ForEach(winners.indices, id: \.self) { i in
                                let w = winners[i]
                                let seat = w.int("seat") ?? (type == "tsumo" ? (result.int("seat") ?? 0) : 0)
                                Text(loc.t(windLabelKeysOnline[seat < seats.count ? (seats[seat].str("wind") ?? "wE") : "wE"] ?? "windE"))
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(Theme.accent)
                                ForEach(w.dictArray("yakuList").indices, id: \.self) { j in
                                    let y = w.dictArray("yakuList")[j]
                                    HStack {
                                        Text(y.str("name") ?? "")
                                        Spacer()
                                        let han = y.int("han") ?? 0
                                        if han > 0 { Text("\(han) han") }
                                    }
                                    .font(.system(size: 12))
                                    .foregroundColor(Theme.textDim)
                                }
                                HStack {
                                    Text("\(loc.t("fuLabel")) \(w.int("fu") ?? 0) · \(loc.t("hanLabel")) \(w.int("han") ?? 0)")
                                    Spacer()
                                    Text("\(w.int("total") ?? 0) \(loc.t("totalPoints"))")
                                }
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(Theme.text)
                            }
                        }
                    }
                }
                .frame(maxHeight: 240)

                Button(loc.t("nextHand"), action: { client.nextHand() }).buttonStyle(PrimaryButtonStyle())
            }
            .padding(20)
            .background(RoundedRectangle(cornerRadius: 14).fill(Theme.bgPanel))
            .padding(30)
        }
    }

    private func matchEndModal(_ points: [Int]) -> some View {
        let seats = state.dictArray("seats")
        let ranked = points.enumerated().map { (seat: $0.offset, points: $0.element) }.sorted { $0.points > $1.points }

        return ZStack {
            Color.black.opacity(0.6).ignoresSafeArea()
            VStack(spacing: 12) {
                Text(loc.t("matchEndTitle")).font(.system(size: 22, weight: .bold)).foregroundColor(Theme.text)
                Text(loc.t("finalStandings")).font(.system(size: 13)).foregroundColor(Theme.textDim)

                ForEach(ranked, id: \.seat) { entry in
                    HStack {
                        let name = entry.seat < seats.count ? (seats[entry.seat].bool("isBot") == true ? loc.t("bot") : (seats[entry.seat].str("name") ?? "")) : ""
                        Text(name)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(Theme.text)
                        Spacer()
                        Text("\(entry.points)")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(Theme.accent)
                    }
                    .padding(.horizontal, 20)
                }

                Button(loc.t("backToMenu"), action: onExit)
                    .buttonStyle(PrimaryButtonStyle())
                    .padding(.top, 8)
            }
            .padding(26)
            .frame(maxWidth: 340)
            .background(RoundedRectangle(cornerRadius: 18).fill(Theme.bgPanel).overlay(RoundedRectangle(cornerRadius: 18).stroke(Theme.borderStrong, lineWidth: 1)))
        }
    }

    private var connectionLostOverlay: some View {
        ZStack {
            Color.black.opacity(0.6).ignoresSafeArea()
            VStack(spacing: 12) {
                Text(loc.t("connectionLost")).foregroundColor(Theme.text)
                Button(loc.t("backToMenu"), action: onExit).buttonStyle(PrimaryButtonStyle())
            }
            .padding(20)
            .background(RoundedRectangle(cornerRadius: 14).fill(Theme.bgPanel))
        }
    }
}

private struct MiniTileChipOnline: View {
    let typeId: String
    var body: some View {
        TileFaceView(typeId: typeId)
            .frame(width: 14, height: 20)
            .background(RoundedRectangle(cornerRadius: 3).fill(Theme.tileFace))
            .overlay(RoundedRectangle(cornerRadius: 3).stroke(Theme.tileEdge, lineWidth: 0.5))
    }
}
