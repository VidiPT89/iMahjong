import XCTest
@testable import iVidiMahjong

final class AcademyTests: XCTestCase {

    func testTwoSidedWaitAcceptsBothEnds() {
        // 123m 456p 789s, a pair of East and an open 45s: waits on 3s and 6s.
        let hand = ["m1", "m2", "m3", "p4", "p5", "p6", "s7", "s8", "s9", "wE", "wE", "s4", "s5"]
        XCTAssertEqual(winningTiles(hand), ["s3", "s6"])
    }

    func testClassicSingleSuitMultiWait() {
        // 1112345678999m is the nine-sided wait: every manzu tile wins.
        let hand = ["m1", "m1", "m1", "m2", "m3", "m4", "m5", "m6", "m7", "m8", "m9", "m9", "m9"]
        XCTAssertEqual(winningTiles(hand), (1...9).map { "m\($0)" })
    }

    func testAcceptanceIgnoresCopiesAlreadySeen() {
        XCTAssertEqual(acceptance(["s3", "s6"], visible: ["s3", "s3", "s6"]), 5)
    }

    func testFuritenFindsWaitsInOwnDiscards() {
        XCTAssertEqual(furitenTiles(waits: ["p3", "p6"], discards: ["wN", "p6", "m1"]), ["p6"])
    }

    func testBestDiscardKeepsTheWiderWait() {
        // Drop the isolated north wind: tenpai on 3s/6s. Any other discard is not tenpai.
        let hand = sortTiles(["m1", "m2", "m3", "p4", "p5", "p6", "s7", "s8", "s9", "wE", "wE", "s4", "s5", "wN"])
        XCTAssertEqual(bestDiscards(discardOptions(hand)), ["wN"])
    }

    func testDragonDoraFollowsWhiteGreenRed() {
        let engine = RiichiEngine(dealerSeat: 0, roundWind: "wE")
        XCTAssertEqual(engine.doraTypeFor("dW"), "dG")
        XCTAssertEqual(engine.doraTypeFor("dG"), "dR")
        XCTAssertEqual(engine.doraTypeFor("dR"), "dW")
        XCTAssertEqual(engine.doraTypeFor("m9"), "m1")
        XCTAssertEqual(engine.doraTypeFor("wN"), "wE")
    }

    func testGeneratedWaitDrillsAreConsistent() {
        var rng = SeededGenerator(seed: 7)
        for level in [0, 1] {
            for _ in 0..<60 {
                let drill = makeWaitDrill(level: level, using: &rng)
                XCTAssertEqual(drill.hand.count, 13)
                XCTAssertFalse(drill.waits.isEmpty)
                XCTAssertTrue(Set(drill.waits).isSubset(of: drill.choices))
                for wait in drill.waits { XCTAssertTrue(checkWin(drill.hand + [wait], []).win) }
            }
        }
    }

    func testGeneratedDiscardDrillsHaveARealChoice() {
        var rng = SeededGenerator(seed: 11)
        for _ in 0..<60 {
            let drill = makeDiscardDrill(using: &rng)
            XCTAssertEqual(drill.hand.count, 14)
            XCTAssertFalse(checkWin(drill.hand, []).win)
            XCTAssertFalse(drill.best.isEmpty)
            XCTAssertLessThan(drill.best.count, drill.options.count)
        }
    }

    /// The itemised fu must add up to exactly what the table scores, and the evaluation
    /// must match the engine's own best result.
    func testScoreDrillsMatchTheEngine() {
        var rng = SeededGenerator(seed: 23)
        for _ in 0..<200 {
            let drill = makeScoreDrill(using: &rng)
            let result = drill.evaluation.result
            XCTAssertEqual(roundedFu(drill.fuParts), result.fu, "\(drill.hand) win \(drill.winTile) \(drill.fuParts)")
            let engineBest = bestYakuResult(checkWin(drill.hand, []), drill.hand, drill.evaluation.context)
            XCTAssertEqual(engineBest?.han, result.han)
            XCTAssertEqual(engineBest?.fu, result.fu)
            XCTAssertTrue(drill.choices.contains(drill.payment.total))
            XCTAssertEqual(Set(drill.choices).count, 4)
        }
    }

    func testPinfuRonIsThirtyFuOneThousandPoints() throws {
        let hand = ["m2", "m3", "m4", "p4", "p5", "p6", "s6", "s7", "s8", "m7", "m8", "m9", "p9", "p9"]
        let ctx = WinContext(concealed: true, openMelds: [], winTile: "m2", winType: .ron, seatWind: "wS", roundWind: "wE",
                             riichi: false, doubleRiichi: false, ippatsu: false, haitei: false, houtei: false, rinshan: false,
                             doraCount: 0, uraDoraCount: 0)
        let eval = try XCTUnwrap(bestEvaluation(hand, ctx))
        XCTAssertEqual(eval.result.yakuList.map(\.name), ["Pinfu"])
        XCTAssertEqual(fuBreakdown(eval), [.pinfu(30)])
        XCTAssertEqual(scorePoints(eval.result, isDealer: false, winType: .ron).total, 1000)
    }

    func testProgressCountsStreaks() {
        let defaults = UserDefaults(suiteName: "academy-tests-\(UUID().uuidString)")!
        let progress = AcademyProgress(defaults: defaults)
        progress.record(.waits, correct: true)
        progress.record(.waits, correct: true)
        progress.record(.waits, correct: false)
        progress.markLessonDone("tiles")
        XCTAssertEqual(progress.stats(.waits), .init(answered: 3, correct: 2, streak: 0, bestStreak: 2))
        XCTAssertEqual(progress.completedLessons, ["tiles"])
    }

    /// Lesson content is checked against the engine, so the text can't drift from the rules.
    func testLessonExamplesAndAnswersFollowTheRules() throws {
        for lesson in ACADEMY_LESSONS {
            let tiles = lesson.examples.flatMap(\.tiles) + lesson.quiz.options.flatMap(\.tiles)
            XCTAssertTrue(tiles.allSatisfy { STANDARD_TYPE_IDS.contains($0) }, lesson.id)
            XCTAssertTrue(lesson.quiz.options.indices.contains(lesson.quiz.answer), lesson.id)
            for example in lesson.examples where example.tiles.count == 14 {
                XCTAssertTrue(checkWin(example.tiles, []).win, "\(lesson.id): \(example.tiles)")
            }
        }
        // Lesson 3: 7-8 waits on 6 or 9.
        let hand = ["m1", "m2", "m3", "p4", "p5", "p6", "s3", "s4", "s5", "wE", "wE", "m7", "m8"]
        XCTAssertEqual(winningTiles(hand), ["m6", "m9"])
        // Lesson 8: 3 han 30 fu, non-dealer ron.
        let result = YakuResult(yakuList: [], han: 3, fu: 30, yakuman: false, yakumanCount: 0)
        XCTAssertEqual(scorePoints(result, isDealer: false, winType: .ron).total, 3900)
        // Lesson 4: the tanyao example scores tanyao.
        let tanyao = ACADEMY_LESSONS.first { $0.id == "yaku" }!.examples[0].tiles
        let ctx = WinContext(concealed: true, openMelds: [], winTile: "s6", winType: .tsumo, seatWind: "wS", roundWind: "wE",
                             riichi: false, doubleRiichi: false, ippatsu: false, haitei: false, houtei: false, rinshan: false,
                             doraCount: 0, uraDoraCount: 0)
        let eval = try XCTUnwrap(bestEvaluation(tanyao, ctx))
        XCTAssertTrue(eval.result.yakuList.contains { $0.name == "Tanyao" })
    }
}
