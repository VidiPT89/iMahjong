import SwiftUI

enum AppScreen {
    case splash, menu, howToPlay, game, levelSelect
    case traditionalSetup, traditionalTable
    case academy, lesson(Int), drill(DrillKind)
}

final class DifficultyStore: ObservableObject {
    @Published var value: Difficulty {
        didSet { UserDefaults.standard.set(value.rawValue, forKey: "ividimahjong-difficulty") }
    }

    init() {
        if let stored = UserDefaults.standard.string(forKey: "ividimahjong-difficulty"), let d = Difficulty(rawValue: stored) {
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
    @State private var screen: AppScreen = .menu
    @State private var hasSave = SaveStore.hasSave()
    @State private var humanSeats: [Bool] = [true, false, false, false]
    @State private var localMatch: LocalMatch?
    @StateObject private var progress = AcademyProgress()

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
                    onLevels: { withAnimation(Theme.ease) { screen = .levelSelect } },
                    onHowToPlay: { withAnimation(Theme.ease) { screen = .howToPlay } },
                    onTraditionalMode: { withAnimation(Theme.ease) { screen = .traditionalSetup } },
                    onAcademy: { withAnimation(Theme.ease) { screen = .academy } },
                    lessonsDone: progress.completedLessons.count
                )
            case .academy:
                AcademyView(
                    progress: progress,
                    onBack: { withAnimation(Theme.ease) { screen = .menu } },
                    onLesson: { i in withAnimation(Theme.ease) { screen = .lesson(i) } },
                    onDrill: { kind in withAnimation(Theme.ease) { screen = .drill(kind) } },
                    onTable: { withAnimation(Theme.ease) { screen = .traditionalSetup } }
                )
            case .lesson(let index):
                LessonView(
                    progress: progress, index: index,
                    onBack: { withAnimation(Theme.ease) { screen = .academy } },
                    onNext: { i in withAnimation(Theme.ease) { screen = .lesson(i) } }
                )
                .id(index)
            case .drill(let kind):
                DrillView(progress: progress, kind: kind, onBack: { withAnimation(Theme.ease) { screen = .academy } })
                    .id(kind)
            case .howToPlay:
                HowToPlayView(onClose: { withAnimation(Theme.ease) { screen = .menu } })
            case .levelSelect:
                LevelSelectView(
                    onBack: { withAnimation(Theme.ease) { screen = .menu } },
                    onSelectLevel: { level in startLevel(level) }
                )
            case .game:
                GameView(engine: engine, onExit: {
                    hasSave = SaveStore.hasSave()
                    withAnimation(Theme.ease) { screen = .menu }
                })
            case .traditionalSetup:
                TraditionalSetupView(
                    humanSeats: $humanSeats,
                    onBack: { withAnimation(Theme.ease) { screen = .menu } },
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
                        withAnimation(Theme.ease) { screen = .traditionalSetup }
                    })
                }
            }
        }
        .environmentObject(loc)
        .transition(.opacity)
        #if DEBUG
        .onAppear(perform: openDebugScreen)
        #endif
    }

    #if DEBUG
    /// Debug builds only: `-ividimahjong-debug-screen <solitaire|levels|level1|riichi|coach|howto|academy|lesson3|waits|discard|score>`
    /// opens that screen directly, so store screenshots can be captured on the Mac without
    /// UI automation. Riichi runs with four bots so the table fills up on its own.
    private func openDebugScreen() {
        let debugScreen = UserDefaults.standard.string(forKey: "ividimahjong-debug-screen")
        switch debugScreen {
        case "solitaire": startNewGame()
        case "levels": screen = .levelSelect
        case "level1": startLevel(1)
        case "howto": screen = .howToPlay
        case "academy": screen = .academy
        case "lesson3": screen = .lesson(2)
        case "waits": screen = .drill(.waits)
        case "discard": screen = .drill(.discard)
        case "score": screen = .drill(.score)
        case "riichi", "coach":
            let match = LocalMatch(isHuman: [debugScreen == "coach", false, false, false])
            localMatch = match
            match.startHand()
            screen = .traditionalTable
        default: break
        }
    }
    #endif

    private func goToMenu() {
        withAnimation(.easeOut(duration: 0.5)) { screen = .menu }
    }

    private func startNewGame() {
        engine.reset(difficulty: difficultyStore.value)
        SaveStore.clear()
        hasSave = false
        withAnimation(Theme.ease) { screen = .game }
    }

    private func startLevel(_ level: Int) {
        engine.startLevel(level)
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
