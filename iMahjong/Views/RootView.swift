import SwiftUI

enum AppScreen {
    case splash, menu, howToPlay, game
    case traditionalModeSelect, traditionalSetup, traditionalTable
}

final class DifficultyStore: ObservableObject {
    @Published var value: Difficulty {
        didSet { UserDefaults.standard.set(value.rawValue, forKey: "imahjong-difficulty") }
    }

    init() {
        if let stored = UserDefaults.standard.string(forKey: "imahjong-difficulty"), let d = Difficulty(rawValue: stored) {
            value = d
        } else {
            value = .easy
        }
    }
}

struct RootView: View {
    @StateObject private var loc = Localization.shared
    @StateObject private var engine = GameEngine()
    @StateObject private var difficultyStore = DifficultyStore()
    @State private var screen: AppScreen = .splash
    @State private var hasSave = SaveStore.hasSave()
    @State private var humanSeats: [Bool] = [true, false, false, false]
    @State private var localMatch: LocalMatch?

    var body: some View {
        ZStack {
            switch screen {
            case .splash:
                SplashView { goToMenu() }
            case .menu:
                MainMenuView(
                    hasSave: hasSave,
                    selectedDifficulty: $difficultyStore.value,
                    onPlay: { startNewGame() },
                    onContinue: { continueGame() },
                    onHowToPlay: { withAnimation(Theme.ease) { screen = .howToPlay } },
                    onTraditionalMode: { withAnimation(Theme.ease) { screen = .traditionalModeSelect } }
                )
            case .howToPlay:
                HowToPlayView(onClose: { withAnimation(Theme.ease) { screen = .menu } })
            case .game:
                GameView(engine: engine, onExit: {
                    SaveStore.save(engine)
                    hasSave = true
                    withAnimation(Theme.ease) { screen = .menu }
                })
            case .traditionalModeSelect:
                TraditionalModeSelectView(
                    onBack: { withAnimation(Theme.ease) { screen = .menu } },
                    onLocal: { withAnimation(Theme.ease) { screen = .traditionalSetup } }
                )
            case .traditionalSetup:
                TraditionalSetupView(
                    humanSeats: $humanSeats,
                    onBack: { withAnimation(Theme.ease) { screen = .traditionalModeSelect } },
                    onStart: {
                        let match = LocalMatch(isHuman: humanSeats)
                        localMatch = match
                        match.startHand()
                        withAnimation(Theme.ease) { screen = .traditionalTable }
                    }
                )
            case .traditionalTable:
                if let localMatch {
                    TraditionalTableView(match: localMatch, onExit: {
                        localMatch.stop()
                        self.localMatch = nil
                        withAnimation(Theme.ease) { screen = .traditionalModeSelect }
                    })
                }
            }
        }
        .environmentObject(loc)
        .transition(.opacity)
    }

    private func goToMenu() {
        withAnimation(.easeOut(duration: 0.5)) { screen = .menu }
    }

    private func startNewGame() {
        engine.reset(difficulty: difficultyStore.value)
        SaveStore.clear()
        hasSave = false
        withAnimation(Theme.ease) { screen = .game }
    }

    private func continueGame() {
        if let snapshot = SaveStore.load() {
            engine.restore(from: snapshot)
        } else {
            engine.reset(difficulty: difficultyStore.value)
        }
        withAnimation(Theme.ease) { screen = .game }
    }
}
