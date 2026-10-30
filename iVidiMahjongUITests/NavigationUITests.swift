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
        app.launchArguments = ["-ividimahjong-lang", lang, "-ividimahjong-difficulty", "medium", "-ividimahjong-coach", "YES"]
        app.launch()

        let academy = app.buttons["academy"]
        XCTAssertTrue(academy.waitForExistence(timeout: 5))
        snapshot("1-menu", lang)

        academy.press()
        let waitsDrill = app.buttons["drill-waits"]
        XCTAssertTrue(app.buttons["lesson-tiles"].waitForExistence(timeout: 5))
        snapshot("2-academy", lang)

        app.buttons["lesson-waits"].press()
        sleep(1)
        snapshot("3-lesson", lang)
        app.buttons["back"].press()

        waitsDrill.press()
        let choices = app.buttons.matching(identifier: "wait-choice")
        XCTAssertTrue(choices.firstMatch.waitForExistence(timeout: 5))
        choices.element(boundBy: 0).press()
        choices.element(boundBy: 2).press()
        app.buttons["check"].press()
        sleep(1)
        snapshot("4-waits", lang)
        app.buttons["back"].press()

        app.buttons["drill-discard"].press()
        let tiles = app.buttons.matching(identifier: "drill-tile")
        XCTAssertTrue(tiles.firstMatch.waitForExistence(timeout: 5))
        tiles.element(boundBy: tiles.count - 1).press()
        sleep(1)
        snapshot("5-discard", lang)
        app.buttons["back"].press()

        app.buttons["drill-score"].press()
        let answers = app.buttons.matching(identifier: "score-choice")
        XCTAssertTrue(answers.firstMatch.waitForExistence(timeout: 5))
        answers.element(boundBy: 1).press()
        sleep(1)
        snapshot("6-score", lang)
        app.buttons["back"].press()
        XCTAssertTrue(app.buttons["drill-score"].waitForExistence(timeout: 5))
        app.buttons["back"].press()

        XCTAssertTrue(app.buttons["riichiTable"].waitForExistence(timeout: 5))
        sleep(1) // let the screen transition settle before tapping
        app.buttons["riichiTable"].press()
        let start = app.buttons[en ? "Start Match" : "Começar Partida"]
        XCTAssertTrue(start.waitForExistence(timeout: 5))
        start.press()
        playSomeRiichiTurns(app, en: en)
        snapshot("7-coached-table", lang)
        app.buttons["back"].press()
        app.buttons[en ? "Back" : "Voltar"].press()

        XCTAssertTrue(app.buttons["solitaire"].waitForExistence(timeout: 5))
        sleep(1)
        app.buttons["solitaire"].press()
        let hint = app.buttons[en ? "Hint" : "Dica"]
        XCTAssertTrue(hint.waitForExistence(timeout: 20))
        sleep(2) // let the deal animation finish
        snapshot("8-solitaire", lang)
        app.buttons["back"].press()
    }

    /// Discards the right-most tile for a few turns (passing on any call offer) so the
    /// table shows rivers rather than an empty opening position.
    private func playSomeRiichiTurns(_ app: XCUIApplication, en: Bool) {
        let yourTurn = app.staticTexts[en ? "Your turn — tap a tile to discard." : "A tua vez — toca numa ficha para descartar."]
        let pass = app.buttons[en ? "Pass" : "Passar"]
        for _ in 0..<7 {
            if pass.exists { pass.press() }
            guard yourTurn.waitForExistence(timeout: 8) else { continue }
            let hand = app.buttons.matching(identifier: "handTile")
            hand.element(boundBy: hand.count - 1).press()
        }
        _ = yourTurn.waitForExistence(timeout: 8)
        if pass.exists { pass.press() }
    }

    private func snapshot(_ name: String, _ lang: String) {
        guard ProcessInfo.processInfo.environment["STORE_SHOTS"] == "1" else { return }
        #if os(macOS)
        let attachment = XCTAttachment(screenshot: XCUIApplication().windows.firstMatch.screenshot())
        #else
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        #endif
        attachment.name = "\(lang)-\(name)"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}

private extension XCUIElement {
    /// tap() on iOS, click() on the Mac.
    func press() {
        #if os(macOS)
        click()
        #else
        tap()
        #endif
    }
}
