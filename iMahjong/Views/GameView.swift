import SwiftUI

private enum ModalKind {
    case none, win, stuck, confirmRestart
}

private let maxHints = 5

struct GameView: View {
    @EnvironmentObject var loc: Localization
    @ObservedObject var engine: GameEngine
    let onExit: () -> Void

    @State private var modal: ModalKind = .none
    @State private var toastMessage: String?
    @State private var hintedIds: Set<Int> = []
    @State private var shakeTokens: [Int: Int] = [:]
    @State private var lastMoveDealOrder: [Int: Double] = [:]

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()

            VStack(spacing: 0) {
                header
                boardArea
            }

            if let message = toastMessage {
                VStack {
                    Spacer()
                    ToastView(message: message).padding(.bottom, 30)
                }
                .zIndex(500)
            }

            switch modal {
            case .win:
                WinModalView(
                    time: formattedTime(engine.elapsedSeconds),
                    moves: engine.moves,
                    score: currentScore,
                    onPlayAgain: { restartGame() },
                    onMenu: { SaveStore.clear(); onExit() }
                ).zIndex(600)
            case .stuck:
                StuckModalView(
                    onShuffle: { performShuffle(); modal = .none },
                    onUndo: { performUndo(); modal = .none },
                    onMenu: onExit
                ).zIndex(600)
            case .confirmRestart:
                ConfirmModalView(
                    message: loc.t("restartConfirm"),
                    onYes: { restartGame() },
                    onCancel: { modal = .none }
                ).zIndex(600)
            case .none:
                EmptyView()
            }
        }
        .onAppear { assignDealOrder() }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 8) {
            HStack(spacing: 6) {
                Button(action: { SaveStore.save(engine); onExit() }) {
                    Image(systemName: "chevron.left")
                        .foregroundColor(Theme.text)
                        .frame(width: 30, height: 30)
                        .background(Circle().fill(Theme.bgPanel2))
                }
                .buttonStyle(.plain)

                Spacer(minLength: 4)

                actionIcon("lightbulb", tip: loc.t("hint"), badge: maxHints - engine.hintsUsed, action: performHint)
                actionIcon("shuffle", tip: loc.t("shuffle"), action: performShuffle)
                actionIcon("arrow.uturn.backward", tip: loc.t("undo"), action: performUndo)
                actionIcon("arrow.clockwise", tip: loc.t("restart"), action: { modal = .confirmRestart })
            }
            .padding(.horizontal, 12)
            .padding(.top, 10)

            HStack(spacing: 0) {
                statGroup(loc.t("time")) {
                    TimelineView(.periodic(from: .now, by: 1)) { _ in
                        Text(formattedTime(engine.elapsedSeconds))
                    }
                }
                statDivider()
                statGroup(loc.t("moves")) { Text("\(engine.moves)") }
                statDivider()
                statGroup(loc.t("score")) { Text("\(currentScore)") }
                statDivider()
                statGroup(loc.t("left")) { Text("\(engine.remaining())") }
            }
        }
        .padding(.bottom, 10)
        .background(Theme.bgPanel.opacity(0.6))
    }

    private func statGroup<V: View>(_ label: String, @ViewBuilder value: () -> V) -> some View {
        HStack(spacing: 4) {
            Text(label).font(.system(size: 9, weight: .semibold)).foregroundColor(Theme.textFaint).textCase(.uppercase)
            value().font(.system(size: 12, weight: .bold)).foregroundColor(Theme.text).monospacedDigit()
        }
        .frame(maxWidth: .infinity)
        .lineLimit(1)
        .minimumScaleFactor(0.7)
    }

    private func statDivider() -> some View {
        Rectangle().fill(Theme.borderStrong).frame(width: 1, height: 14)
    }

    private func actionIcon(_ systemName: String, tip: String, badge: Int? = nil, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            ZStack(alignment: .topTrailing) {
                Image(systemName: systemName)
                    .font(.system(size: 14))
                    .foregroundColor(Theme.text)
                    .frame(width: 30, height: 30)
                    .background(Circle().fill(Theme.bgPanel2))
                if let badge, badge >= 0 {
                    Text("\(badge)")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(Theme.bg)
                        .padding(3)
                        .background(Circle().fill(Theme.accent))
                        .offset(x: 4, y: -4)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(tip)
    }

    // MARK: - Board

    private var boardArea: some View {
        let extents = BoardExtents(tiles: engine.tiles)
        let boardW = BoardGeometry.boardWidth(extents)
        let boardH = BoardGeometry.boardHeight(extents)
        return GeometryReader { outer in
            let scale = min(
                outer.size.width / boardW,
                outer.size.height / boardH,
                1.5
            )
            ZStack {
                ForEach(engine.tiles) { tile in
                    if !tile.removed {
                        let point = BoardGeometry.point(for: tile, in: extents)
                        TileView(
                            tile: tile,
                            width: BoardGeometry.tileW,
                            height: BoardGeometry.tileH,
                            isFree: engine.isFree(tile),
                            isSelected: engine.selectedId == tile.id,
                            isHinted: hintedIds.contains(tile.id),
                            shakeToken: shakeTokens[tile.id] ?? 0,
                            dealDelay: lastMoveDealOrder[tile.id] ?? 0
                        )
                        .position(point)
                        .zIndex(BoardGeometry.zIndex(for: tile))
                        .transition(.asymmetric(
                            insertion: .identity,
                            removal: .scale(scale: 0.6).combined(with: .opacity)
                        ))
                        .onTapGesture { handleTap(tile) }
                        .id(tile.id)
                    }
                }
            }
            .frame(width: boardW, height: boardH)
            .scaleEffect(scale)
            .frame(width: outer.size.width, height: outer.size.height)
        }
    }

    // MARK: - Actions

    private func assignDealOrder() {
        var order: [Int: Double] = [:]
        for (i, tile) in engine.tiles.shuffled().enumerated() {
            order[tile.id] = Double(i) * 0.006
        }
        lastMoveDealOrder = order
    }

    private func handleTap(_ tile: GameTile) {
        let result = withAnimation(.easeOut(duration: 0.25)) { engine.select(tile.id) }
        switch result {
        case .matched(_, _, let won):
            SaveStore.save(engine)
            if won {
                SaveStore.clear()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { modal = .win }
            } else if engine.isStuck() {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { modal = .stuck }
            }
        case .mismatch(let previous, _):
            triggerShake(previous.id)
        case .blocked(let t):
            triggerShake(t.id)
        default:
            break
        }
    }

    private func triggerShake(_ id: Int) {
        shakeTokens[id, default: 0] += 1
    }

    private func performHint() {
        guard engine.hintsUsed < maxHints else {
            showToast(loc.t("noHintsLeft"))
            return
        }
        guard let (a, b) = engine.findHint() else { return }
        engine.useHint()
        hintedIds = [a.id, b.id]
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.3) {
            hintedIds = []
        }
    }

    private func restartGame() {
        withAnimation(Theme.ease) { engine.reset() }
        SaveStore.clear()
        assignDealOrder()
        modal = .none
    }

    private func performShuffle() {
        if !engine.reshuffle() {
            showToast(loc.t("shuffleImpossible"))
        } else {
            SaveStore.save(engine)
        }
    }

    private func performUndo() {
        let result = withAnimation(Theme.ease) { engine.undo() }
        if result == nil {
            showToast(loc.t("noMoreUndo"))
        } else {
            SaveStore.save(engine)
        }
    }

    private func showToast(_ message: String) {
        withAnimation { toastMessage = message }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation { toastMessage = nil }
        }
    }

    private var currentScore: Int {
        let pairsCleared = (144 - engine.remaining()) / 2
        return max(0, pairsCleared * 100 - engine.hintsUsed * 30)
    }

    private func formattedTime(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds))
        return String(format: "%02d:%02d", total / 60, total % 60)
    }
}
