import SwiftUI

enum AppScreen {
    case splash, menu, howToPlay, game
}

struct RootView: View {
    @StateObject private var loc = Localization.shared
    @StateObject private var engine = GameEngine()
    @State private var screen: AppScreen = .splash
    @State private var hasSave = SaveStore.hasSave()

    var body: some View {
        ZStack {
            switch screen {
            case .splash:
                SplashView { goToMenu() }
            case .menu:
                MainMenuView(
                    hasSave: hasSave,
                    onPlay: { startNewGame() },
                    onContinue: { continueGame() },
                    onHowToPlay: { withAnimation(Theme.ease) { screen = .howToPlay } }
                )
            case .howToPlay:
                HowToPlayView(onClose: { withAnimation(Theme.ease) { screen = .menu } })
            case .game:
                GameView(engine: engine, onExit: {
                    SaveStore.save(engine)
                    hasSave = true
                    withAnimation(Theme.ease) { screen = .menu }
                })
            }
        }
        .environmentObject(loc)
        .transition(.opacity)
    }

    private func goToMenu() {
        withAnimation(.easeOut(duration: 0.5)) { screen = .menu }
    }

    private func startNewGame() {
        engine.reset()
        SaveStore.clear()
        hasSave = false
        withAnimation(Theme.ease) { screen = .game }
    }

    private func continueGame() {
        if let snapshot = SaveStore.load() {
            engine.restore(from: snapshot)
        } else {
            engine.reset()
        }
        withAnimation(Theme.ease) { screen = .game }
    }
}
