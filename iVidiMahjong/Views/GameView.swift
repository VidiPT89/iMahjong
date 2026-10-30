import SwiftUI

private enum ModalKind {
    case none, win, stuck, confirmRestart
}

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}

struct GameView: View {
    @EnvironmentObject var loc: Localization
    @Environment(\.scenePhase) private var scenePhase
    @ObservedObject var engine: GameEngine
    let onExit: () -> Void

    @State private var modal: ModalKind = .none
    @State private var transitionTask: Task<Void, Never>?
    @State private var toastMessage: String?
    @State private var toastTask: Task<Void, Never>?
    @State private var hintedIds: Set<Int> = []
    @State private var hintTask: Task<Void, Never>?
    @State private var shakeTokens: [Int: Int] = [:]
    @State private var lastMoveDealOrder: [Int: Double] = [:]

    // Pinch-to-zoom only (no panning — the board always stays centered and fully visible,
    // it just scales up/down) on top of the auto-fit scale. `userZoom` is the committed
    // value; `magnifyDelta` tracks the in-flight gesture and resets to 1 automatically when
    // fingers lift, so committing only has to happen once in `onEnded`.
    @State private var userZoom: CGFloat = 1
    @GestureState private var magnifyDelta: CGFloat = 1

    private let minUserZoom: CGFloat = 1
    private let maxUserZoom: CGFloat = 3

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
                    subtitle: engine.difficulty == .infinite ? loc.t("allLevelsComplete") : nil,
                    onPlayAgain: { restartGame(wholeRun: true) },
                    onMenu: { SaveStore.clear(); onExit() }
                ).zIndex(600)
            case .stuck:
                StuckModalView(
                    onShuffle: { performShuffle(); modal = .none },
                    onUndo: { performUndo(); modal = .none },
                    onMenu: { SaveStore.clear(); onExit() }
                ).zIndex(600)
            case .confirmRestart:
                ConfirmModalView(
                    message: loc.t("restartConfirm"),
                    onYes: { restartGame(wholeRun: false) },
                    onCancel: { modal = .none }
                ).zIndex(600)
            case .none:
                EmptyView()
            }
        }
        .onAppear {
            engine.resume()
            assignDealOrder()
            if engine.isWon() && engine.difficulty == .infinite { handleInfiniteLevelCleared() }
            else if !engine.isWon() { SaveStore.save(engine) }
        }
        .onDisappear {
            transitionTask?.cancel()
            toastTask?.cancel()
            hintTask?.cancel()
            engine.pause()
        }
        .onChange(of: scenePhase) { phase in
            if phase == .active && !engine.isWon() { engine.resume() }
            else {
                engine.pause()
                if !engine.isWon() { SaveStore.save(engine) }
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 8) {
            HStack(spacing: 6) {
                Button(action: { SaveStore.save(engine); onExit() }) {
                    Image(systemName: "chevron.left")
                        .foregroundColor(Theme.text)
                        .frame(width: 44, height: 44)
                        .background(Circle().fill(Theme.bgPanel2))
                }
                .buttonStyle(.plain)

                Spacer(minLength: 4)

                actionIcon("lightbulb", tip: loc.t("hint"), action: performHint)
                actionIcon("shuffle", tip: loc.t("shuffle"), action: performShuffle)
                actionIcon("arrow.uturn.backward", tip: loc.t("undo"), action: performUndo)
                actionIcon("arrow.clockwise", tip: loc.t("restart"), action: { modal = .confirmRestart })
            }
            .padding(.horizontal, 12)
            .padding(.top, 10)

            HStack(spacing: 0) {
                if engine.difficulty == .infinite {
                    statGroup(loc.t("level")) { Text("\(engine.level)") }
                    statDivider()
                }
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

    private func actionIcon(_ systemName: String, tip: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 14))
                .foregroundColor(Theme.text)
                .frame(width: 44, height: 44)
                .background(Circle().fill(Theme.bgPanel2))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(tip)
    }

    // MARK: - Board

    private var boardArea: some View {
        let extents = BoardExtents(tiles: engine.tiles)
        let boardW = BoardGeometry.boardWidth(extents)
        let boardH = BoardGeometry.boardHeight(extents)
        // Computed once per body evaluation (not once per tile) — see freeTileIds()'s doc
        // comment for why calling engine.isFree(tile) inside the ForEach below was the real
        // source of the tap/match lag: it turned every redraw into an O(n²) scan.
        let freeIds = engine.freeTileIds()
        return GeometryReader { outer in
            let fitScale = min(
                outer.size.width / boardW,
                outer.size.height / boardH,
                1.5
            )
            let zoom = (userZoom * magnifyDelta).clamped(to: minUserZoom...maxUserZoom)

            let magnify = MagnificationGesture()
                .updating($magnifyDelta) { value, state, _ in state = value }
                .onEnded { value in
                    userZoom = (userZoom * value).clamped(to: minUserZoom...maxUserZoom)
                }

            ZStack {
                ForEach(engine.tiles) { tile in
                    if !tile.removed {
                        let point = BoardGeometry.point(for: tile, in: extents)
                        TileView(
                            tile: tile,
                            width: BoardGeometry.tileW,
                            height: BoardGeometry.tileH,
                            isFree: freeIds.contains(tile.id),
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
                        // highPriorityGesture, not onTapGesture: the board container below
                        // also recognizes a double-tap (to reset zoom), and a plain single-tap
                        // gesture anywhere in the same hierarchy as a double-tap gesture has to
                        // wait out iOS's ~0.3s double-tap window before it's allowed to fire.
                        // Giving the tile's tap priority skips that wait entirely.
                        .highPriorityGesture(TapGesture().onEnded { handleTap(tile) })
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(tileAccessibilityName(tile.typeId ?? "", loc))
                        .accessibilityAddTraits(.isButton)
                        .accessibilityAction { handleTap(tile) }
                        .id(tile.id)
                    }
                }
            }
            .frame(width: boardW, height: boardH)
            .scaleEffect(fitScale * zoom)
            .frame(width: outer.size.width, height: outer.size.height)
            .contentShape(Rectangle())
            .simultaneousGesture(magnify)
            .onTapGesture(count: 2) {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    userZoom = 1
                }
            }
        }
    }

    // MARK: - Actions

    /// Deals tiles from the center of the board outward, so the pyramid appears to build up
    /// from the middle rather than from its edges.
    private func assignDealOrder() {
        let extents = BoardExtents(tiles: engine.tiles)
        let centerX = Double(extents.minX + extents.maxX) / 2
        let centerY = Double(extents.minY + extents.maxY) / 2

        let sorted = engine.tiles.sorted { a, b in
            let da = pow(Double(a.x) - centerX, 2) + pow(Double(a.y) - centerY, 2)
            let db = pow(Double(b.x) - centerX, 2) + pow(Double(b.y) - centerY, 2)
            return da < db
        }

        var order: [Int: Double] = [:]
        for (i, tile) in sorted.enumerated() {
            order[tile.id] = Double(i) * 0.006
        }
        lastMoveDealOrder = order
    }

    private func handleTap(_ tile: GameTile) {
        let result = withAnimation(.easeOut(duration: 0.25)) { engine.select(tile.id) }
        switch result {
        case .selected:
            SoundManager.tilePick()
        case .matched(_, _, let won):
            SoundManager.match()
            SaveStore.save(engine)
            if won {
                engine.pause()
                if engine.difficulty == .infinite {
                    handleInfiniteLevelCleared()
                } else {
                    SaveStore.clear()
                    Leaderboard.recordWin(difficulty: engine.difficulty, timeSeconds: engine.elapsedSeconds, moves: engine.moves)
                    SoundManager.win()
                    scheduleTransition(after: 0.3) { modal = .win }
                }
            } else if engine.isStuck() {
                scheduleTransition(after: 0.2) { modal = .stuck }
            }
        case .mismatch(let previous, _):
            SoundManager.mismatch()
            triggerShake(previous.id)
        case .blocked(let t):
            SoundManager.mismatch()
            triggerShake(t.id)
        default:
            break
        }
    }

    private func triggerShake(_ id: Int) {
        shakeTokens[id, default: 0] += 1
    }

    /// Levels mode shows the win modal only once the whole ladder (LEVELS_MAX_LEVEL) is
    /// cleared — before that, clearing a level just chains straight into the next (bigger)
    /// one, so a run keeps going instead of stopping at every step. Progress (the highest
    /// level reached) is saved after every level, not just when the player eventually
    /// quits, so it survives the app being killed mid-run.
    private func handleInfiniteLevelCleared() {
        let clearedLevel = engine.level
        let isNewRecord = Leaderboard.recordInfiniteLevel(clearedLevel)
        SoundManager.win()

        if clearedLevel >= LEVELS_MAX_LEVEL {
            SaveStore.clear()
            scheduleTransition(after: 0.3) { modal = .win }
            return
        }

        showToast(
            (isNewRecord ? loc.t("newRecordLevel") : loc.t("levelCleared"))
                .replacingOccurrences(of: "{level}", with: "\(clearedLevel)")
        )
        scheduleTransition(after: 0.9) {
            engine.dealNextInfiniteLevel()
            engine.resume()
            assignDealOrder()
            SaveStore.save(engine)
        }
    }

    private func scheduleTransition(after delay: Double, _ action: @escaping () -> Void) {
        transitionTask?.cancel()
        transitionTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            guard !Task.isCancelled else { return }
            action()
        }
    }

    private func performHint() {
        guard let (a, b) = engine.findHint() else { return }
        engine.useHint()
        SaveStore.save(engine)
        hintedIds = [a.id, b.id]
        hintTask?.cancel()
        hintTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_300_000_000)
            guard !Task.isCancelled else { return }
            hintedIds = []
        }
    }

    /// Solitaire always deals a fresh board. In Levels, restarting mid-run replays only the
    /// current level; "play again" after clearing the whole ladder starts over from level 1.
    private func restartGame(wholeRun: Bool) {
        transitionTask?.cancel()
        hintedIds = []
        withAnimation(Theme.ease) {
            if engine.difficulty == .infinite && !wholeRun {
                engine.startLevel(engine.level)
            } else {
                engine.reset()
            }
        }
        SaveStore.save(engine)
        assignDealOrder()
        modal = .none
        userZoom = 1
    }

    private func performShuffle() {
        guard !engine.isWon() else { return }
        if !engine.reshuffle() {
            showToast(loc.t("shuffleImpossible"))
        } else {
            SaveStore.save(engine)
        }
    }

    private func performUndo() {
        guard !engine.isWon() else { return }
        let result = withAnimation(Theme.ease) { engine.undo() }
        if result == nil {
            showToast(loc.t("noMoreUndo"))
        } else {
            SaveStore.save(engine)
        }
    }

    private func showToast(_ message: String) {
        withAnimation { toastMessage = message }
        toastTask?.cancel()
        toastTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            guard !Task.isCancelled else { return }
            withAnimation { toastMessage = nil }
        }
    }

    private var currentScore: Int {
        let pairsCleared = (engine.tiles.count - engine.remaining()) / 2
        return max(0, pairsCleared * 100 - engine.hintsUsed * 30)
    }

    private func formattedTime(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds))
        return String(format: "%02d:%02d", total / 60, total % 60)
    }
}
