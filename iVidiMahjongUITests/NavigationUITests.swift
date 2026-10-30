import XCTest

/// Walks the main screens in a real app process: a smoke test for navigation, and with
/// STORE_SHOTS=1 (TEST_RUNNER_STORE_SHOTS=1 via xcodebuild) it also keeps one screenshot
/// per screen as an attachment for the App Store listing.
final class NavigationUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    func testMainScreensInEnglish() { walkMainScreens(lang: "en") }
    func testMainScreensInPortuguese() { walkMainScreens(lang: "pt") }

    private func walkMainScreens(lang: String) {
        let en = lang == "en"
        let app = XCUIApplication()
        app.launchArguments = ["-ividimahjong-lang", lang, "-ividimahjong-difficulty", "medium"]
        app.launch()

        let menuPlay = app.buttons[en ? "Play" : "Jogar"]
        app.staticTexts[en ? "Tap to continue" : "Toque para continuar"].tap()
        XCTAssertTrue(menuPlay.waitForExistence(timeout: 5))
        snapshot("1-menu", lang)

        menuPlay.tap()
        let hint = app.buttons[en ? "Hint" : "Dica"]
        XCTAssertTrue(hint.waitForExistence(timeout: 5))
        sleep(2) // let the deal animation finish
        hint.tap()
        sleep(1)
        snapshot("2-solitaire", lang)
        app.buttons.element(boundBy: 0).tap() // back chevron

        app.buttons[en ? "Levels" : "Níveis"].tap()
        XCTAssertTrue(app.buttons["1"].waitForExistence(timeout: 5))
        snapshot("3-levels", lang)
        app.buttons["1"].tap()
        XCTAssertTrue(hint.waitForExistence(timeout: 5))
        sleep(2)
        snapshot("4-level-1", lang)
        app.buttons.element(boundBy: 0).tap()

        app.buttons[en ? "4-Player (Riichi)" : "4 Jogadores (Riichi)"].tap()
        let start = app.buttons[en ? "Start Match" : "Começar Partida"]
        XCTAssertTrue(start.waitForExistence(timeout: 5))
        start.tap()
        playSomeRiichiTurns(app, en: en)
        snapshot("5-riichi", lang)
        app.buttons.element(boundBy: 0).tap()
        app.buttons[en ? "Back" : "Voltar"].tap()

        app.buttons[en ? "How to Play" : "Como Jogar"].tap()
        sleep(1)
        snapshot("6-how-to-play", lang)
    }

    /// Discards the right-most tile for a few turns (passing on any call offer) so the
    /// table shows rivers rather than an empty opening position.
    private func playSomeRiichiTurns(_ app: XCUIApplication, en: Bool) {
        let yourTurn = app.staticTexts[en ? "Your turn — tap a tile to discard." : "A tua vez — toca numa ficha para descartar."]
        let pass = app.buttons[en ? "Pass" : "Passar"]
        for _ in 0..<7 {
            if pass.exists { pass.tap() }
            guard yourTurn.waitForExistence(timeout: 8) else { continue }
            app.buttons.element(boundBy: 14).tap()
        }
        _ = yourTurn.waitForExistence(timeout: 8)
        if pass.exists { pass.tap() }
    }

    private func snapshot(_ name: String, _ lang: String) {
        guard ProcessInfo.processInfo.environment["STORE_SHOTS"] == "1" else { return }
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = "\(lang)-\(name)"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
