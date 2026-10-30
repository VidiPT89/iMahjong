import SwiftUI

private enum ModalKind {
    case none, win, stuck, confirmRestart, nextLevel
}

struct GameView: View {
    @EnvironmentObject var loc: Localization
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("ividimahjong-realistic-overhead") private var overhead = false
    @State private var boardGeneration = 0
    @State private var pairStreak = 0
    @State private var matchMessage: String?
    @State private var celebrationTask: Task<Void, Never>?
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
    var body: some View {
        ZStack {
            Color(red: 0.085, green: 0.072, blue: 0.060).ignoresSafeArea()

            VStack(spacing: 0) {
                header
                guidance
                boardArea
                    .overlay(alignment: .top) {
                        if let matchMessage {
                            Text(matchMessage).font(.system(.headline, design: .rounded)).foregroundColor(Theme.accent)
                                .padding(.horizontal, 20).padding(.vertical, 10)
                                .background(.ultraThinMaterial, in: Capsule())
                                .padding(.top, 8).transition(.opacity).allowsHitTesting(false)
                        }
                    }
                controls
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
            case .nextLevel:
                ModalOverlay {
                    Image(systemName: "checkmark.circle.fill").font(.system(size: 44, design: .rounded)).foregroundColor(Theme.accent)
                    Text(loc.lang == .pt ? "Nível concluído" : "Level complete")
                        .font(.system(.title2, design: .rounded, weight: .bold)).foregroundColor(Theme.text)
                    Button(loc.lang == .pt ? "Próximo nível" : "Next level") {
                        engine.dealNextInfiniteLevel()
                        engine.resume()
                        assignDealOrder()
                        SaveStore.save(engine)
                        modal = .none
                    }.buttonStyle(PrimaryButtonStyle())
                    Button(loc.t("backToMenu"), action: onExit).buttonStyle(GhostButtonStyle())
                }.zIndex(600)
            case .none:
                EmptyView()
            }
        }
        .onAppear {
            engine.resume()
            assignDealOrder()
            if engine.isWon() && engine.difficulty == .infinite { handleInfiniteLevelCleared() }
            else if !engine.isWon() {
                SaveStore.save(engine)
                if engine.isStuck() { modal = .stuck }
            }
        }
        .onDisappear {
            transitionTask?.cancel()
            toastTask?.cancel()
            hintTask?.cancel()
            celebrationTask?.cancel()
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
        HStack {
            BackButton(action: { SaveStore.save(engine); onExit() })
            VStack(alignment: .leading, spacing: 4) {
                Text(engine.difficulty == .infinite ? "\(loc.t("level")) \(engine.level)" : (loc.lang == .pt ? "Solitário" : "Solitaire"))
                    .font(.system(.headline, design: .rounded)).foregroundColor(Theme.text)
                Text(loc.lang == .pt ? "\(engine.remaining() / 2) pares por encontrar" : "\(engine.remaining() / 2) pairs remaining")
                    .font(.system(.subheadline, design: .rounded)).foregroundColor(Theme.textDim)
            }
            Spacer()
            Menu {
                Button(loc.lang == .pt ? "Perspetiva 3D" : "3D perspective") { overhead = false }
                Button(loc.lang == .pt ? "Vista de cima" : "Top view") { overhead = true }
            } label: {
                Image(systemName: "paintpalette").frame(width: 44, height: 44)
            }.menuStyle(.borderlessButton)
                .fixedSize().foregroundColor(Theme.accent)
                .accessibilityLabel(loc.lang == .pt ? "Aspeto da mesa" : "Table appearance")
            Button(action: { modal = .confirmRestart }) {
                Image(systemName: "arrow.clockwise").frame(width: 44, height: 44)
            }.buttonStyle(.plain).foregroundColor(Theme.textDim).accessibilityLabel(loc.t("restart"))
        }.padding(12)
    }

    private var guidance: some View {
        VStack(spacing: 8) {
            ProgressView(value: Double(engine.tiles.count - engine.remaining()), total: Double(max(1, engine.tiles.count)))
                .tint(Theme.accent)
            Text(engine.selectedId == nil
                 ? (loc.lang == .pt ? "Junta duas peças iguais com um lado livre." : "Match two identical tiles with a free side.")
                 : selectionGuidance)
                .font(.system(.subheadline, design: .rounded)).foregroundColor(Theme.textDim)
                .multilineTextAlignment(.center).frame(minHeight: 36)
        }.padding(.horizontal, 20)
    }

    private var selectionGuidance: String {
        if engine.freeTiles().contains(where: matchesSelection) {
            return loc.lang == .pt ? "Escolhe uma das peças destacadas para formar o par." : "Choose a highlighted tile to make a pair."
        }
        return loc.lang == .pt ? "Esta peça ainda não tem par livre. Escolhe outra." : "This tile has no free match yet. Choose another."
    }

    private var controls: some View {
        HStack(spacing: 12) {
            actionIcon("lightbulb", tip: loc.t("hint"), action: performHint)
            actionIcon("arrow.uturn.backward", tip: loc.t("undo"), action: performUndo)
            actionIcon("shuffle", tip: loc.t("shuffle"), action: performShuffle)
        }.frame(maxWidth: 480).padding(.horizontal, 16).padding(.vertical, 12)
    }

    private func actionIcon(_ systemName: String, tip: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 5) {
                Image(systemName: systemName).font(.system(size: 18, weight: .medium, design: .rounded))
                Text(tip).font(.system(.caption, design: .rounded)).lineLimit(1).minimumScaleFactor(0.7)
            }.foregroundColor(Theme.text).frame(maxWidth: .infinity).frame(minHeight: 52)
                .background(RoundedRectangle(cornerRadius: 12).fill(Theme.bgPanel2))
        }.buttonStyle(.plain).accessibilityLabel(tip)
    }

    private func matchesSelection(_ tile: GameTile) -> Bool {
        guard let id = engine.selectedId, id != tile.id,
              let selected = engine.getTile(id) else { return false }
        return tilesMatch(selected.typeId ?? "", tile.typeId ?? "")
    }

    // MARK: - Board

    private var boardArea: some View {
        let free = engine.freeTileIds()
        let matches = Set(engine.tiles.filter { free.contains($0.id) && matchesSelection($0) }.map(\.id))
        return Board3DView(tiles: engine.tiles, freeIDs: free, selectedID: engine.selectedId,
                           highlightedIDs: hintedIds.union(matches), shakeTokens: shakeTokens,
                           generation: boardGeneration, overhead: overhead) { id in
            if let tile = engine.getTile(id) { handleTap(tile) }
        }
    }

    // MARK: - Actions

    private func assignDealOrder() {
        boardGeneration += 1
        pairStreak = 0
        matchMessage = nil
    }

    private func celebratePair() {
        pairStreak += 1
        celebrationTask?.cancel()
        let message = pairStreak > 1
            ? (loc.lang == .pt ? "\(pairStreak) pares seguidos!" : "\(pairStreak) pairs in a row!")
            : (loc.lang == .pt ? "Belo par!" : "Nice match!")
        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.2)) { matchMessage = message }
        celebrationTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            guard !Task.isCancelled else { return }
            withAnimation { matchMessage = nil }
        }
    }

    private func handleTap(_ tile: GameTile) {
        let result = withAnimation(.easeOut(duration: 0.25)) { engine.select(tile.id) }
        switch result {
        case .selected:
            hintedIds = []
            SoundManager.tilePick()
        case .matched(_, _, let won):
            celebratePair()
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
                    scheduleTransition(after: 0.8) { modal = .win }
                }
            } else if engine.isStuck() {
                scheduleTransition(after: 0.2) { modal = .stuck }
            }
        case .mismatch(let previous, _):
            pairStreak = 0
            SoundManager.mismatch()
            triggerShake(previous.id)
        case .blocked(let t):
            pairStreak = 0
            SoundManager.mismatch()
            triggerShake(t.id)
            showToast(loc.lang == .pt ? "Liberta um dos lados e retira as peças por cima." : "Clear either side and remove any tiles on top.")
        default:
            break
        }
    }

    private func triggerShake(_ id: Int) {
        shakeTokens[id, default: 0] += 1
    }

    /// Keep the cleared board visible until the player chooses to continue.
    private func handleInfiniteLevelCleared() {
        engine.pause()
        let clearedLevel = engine.level
        _ = Leaderboard.recordInfiniteLevel(clearedLevel)
        SoundManager.win()

        if clearedLevel >= LEVELS_MAX_LEVEL {
            SaveStore.clear()
            scheduleTransition(after: 0.8) { modal = .win }
            return
        }

        SaveStore.save(engine)
        scheduleTransition(after: 0.8) { modal = .nextLevel }
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
        guard let (a, b) = engine.findHint() else {
            if !engine.isWon() { modal = .stuck }
            return
        }
        pairStreak = 0
        engine.useHint()
        SaveStore.save(engine)
        hintedIds = [a.id, b.id]
        hintTask?.cancel()
        hintTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 4_000_000_000)
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
    }

    private func performShuffle() {
        guard !engine.isWon() else { return }
        hintedIds = []
        pairStreak = 0
        if !engine.reshuffle() {
            showToast(loc.t("shuffleImpossible"))
        } else {
            SaveStore.save(engine)
        }
    }

    private func performUndo() {
        guard !engine.isWon() else { return }
        hintedIds = []
        pairStreak = 0
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
