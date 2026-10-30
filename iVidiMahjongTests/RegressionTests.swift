import XCTest
@testable import iVidiMahjong

final class RegressionTests: XCTestCase {
    private let waitingHand = ["m1", "m2", "m3", "p1", "p2", "p3", "s1", "s2", "s3", "wE", "wE", "wE", "dR"]

    private func readyGame() -> RiichiEngine {
        let game = RiichiEngine()
        game.seats[0].hand = waitingHand + ["p9"]
        game.turnDrawnTile = "p9"
        game.phase = .discard
        return game
    }

    func testRiichiOffersTenpaiDiscardsAndLocksLaterDiscards() {
        let game = readyGame()
        XCTAssertTrue(game.canDeclareRiichi(0))
        XCTAssertTrue(game.declareRiichi(0))
        XCTAssertEqual(game.legalDiscards(), ["dR", "p9"])
        XCTAssertEqual(game.seats[0].points, 24000)
        game.discard("m1")
        XCTAssertEqual(game.phase, .discard)
        game.discard("p9")
        XCTAssertTrue(game.seats[0].ippatsuActive)
        _ = game.resolveReactions([:])
        XCTAssertTrue(game.seats[0].ippatsuActive)
        game.currentSeat = 0
        _ = game.draw()
        XCTAssertEqual(game.legalDiscards(), [game.turnDrawnTile!])
    }

    func testInvalidDiscardDoesNotCrashOrChangeTheHand() {
        let game = readyGame()
        let before = game.seats[0].hand
        game.discard("unknown")
        XCTAssertEqual(game.seats[0].hand, before)
        XCTAssertNil(game.lastDiscard)
    }

    func testTemporaryFuritenClearsOnOwnDrawExceptAfterRiichi() {
        let game = RiichiEngine()
        game.seats[0].furitenUntilNextDraw = true
        _ = game.draw()
        XCTAssertFalse(game.seats[0].furitenUntilNextDraw)
        game.seats[0].riichi = true
        game.seats[0].furitenUntilNextDraw = true
        game.phase = .draw
        _ = game.draw()
        XCTAssertTrue(game.seats[0].furitenUntilNextDraw)
    }

    func testFuritenUsesEveryWaitAndKeepsCalledDiscardHistory() {
        let game = RiichiEngine()
        game.seats[1].hand = ["m2", "m3", "p1", "p2", "p3", "s1", "s2", "s3", "wE", "wE", "wE", "dR", "dR"]
        game.lastDiscard = (0, "m4")
        game.phase = .reaction
        XCTAssertTrue(game.canRon(1))
        game.seats[1].discardHistory = ["m1"]
        XCTAssertFalse(game.canRon(1))
    }

    func testDuplicateDoraIndicatorsMultiplyTheBonus() {
        XCTAssertEqual(RiichiEngine().countDora(["m2", "m2", "p2"], [], ["m1", "m1"]), 4)
    }

    func testKanDrawKeepsIndicatorsStableAndConsumesLiveWallTile() {
        let game = readyGame()
        game.seats[0].hand = ["m1", "m1", "m1", "m1", "p1", "p2", "p3", "s1", "s2", "s3", "wE", "wE", "wE", "dR"]
        let dora = game.doraIndicators()[0]
        let ura = game.uraDoraIndicators()[0]
        let wallCount = game.liveWall.count
        XCTAssertNotNil(game.callAnkan(0, "m1"))
        _ = game.draw()
        XCTAssertEqual(game.deadWall.count, 14)
        XCTAssertEqual(game.liveWall.count, wallCount - 1)
        XCTAssertEqual(game.doraIndicators()[0], dora)
        XCTAssertEqual(game.uraDoraIndicators()[0], ura)
        XCTAssertEqual(game.uraDoraIndicators().count, 2)
    }

    func testKanUnavailableWithFourKansOrNoLiveWall() {
        let game = readyGame()
        game.seats[0].hand = Array(repeating: "m1", count: 4)
        game.kanCount = 4
        XCTAssertTrue(game.canAnkan(0).isEmpty)
        game.kanCount = 0
        game.liveWall = []
        XCTAssertTrue(game.canAnkan(0).isEmpty)
    }

    func testKokushiRejectsMissingOrphansAndInvalidCounts() {
        let invalid = ["m1", "m1", "m1", "m9", "p1", "p9", "s1", "s9", "wE", "wS", "wW", "wN", "dR", "dG"]
        XCTAssertFalse(isKokushiMusou(invalid))
        XCTAssertFalse(checkWin(invalid, []).win)
        XCTAssertFalse(checkWin(Array(repeating: "m1", count: 14), []).win)
    }

    func testSnapshotRejectsInvalidHistoryAndDuplicateIDsWithoutMutatingGame() {
        let game = GameEngine(difficulty: .easy)
        let original = game.tiles
        var snapshot = game.makeSnapshot()
        XCTAssertTrue(snapshot.isValid)
        snapshot.historyPairs = [[1]]
        XCTAssertFalse(game.restore(from: snapshot))
        XCTAssertEqual(game.tiles, original)
        snapshot = game.makeSnapshot()
        snapshot.tiles[1] = snapshot.tiles[0]
        XCTAssertFalse(snapshot.isValid)
        snapshot = game.makeSnapshot()
        snapshot.elapsedSeconds = .infinity
        XCTAssertFalse(snapshot.isValid)
    }

    func testSnapshotRoundTripAfterMatchUndoAndShuffle() throws {
        let game = GameEngine(difficulty: .medium)
        let pair = game.provenSolveOrder[0]
        game.select(pair.0)
        game.select(pair.1)
        XCTAssertTrue(game.reshuffle())
        let encoded = try JSONEncoder().encode(game.makeSnapshot())
        let snapshot = try JSONDecoder().decode(GameSnapshot.self, from: encoded)
        let restored = GameEngine()
        XCTAssertTrue(restored.restore(from: snapshot))
        XCTAssertEqual(restored.tiles, game.tiles)
        XCTAssertNotNil(restored.undo())
        XCTAssertTrue(restored.makeSnapshot().isValid)
    }

    func testLevelsAreClampedAndStopAtFifteen() {
        let game = GameEngine()
        game.startLevel(-100)
        XCTAssertEqual(game.level, 1)
        game.startLevel(Int.max)
        XCTAssertEqual(game.level, 15)
        game.dealNextInfiniteLevel()
        XCTAssertEqual(game.level, 15)
    }

    func testPausedTimerDoesNotAccumulateTime() {
        let game = GameEngine()
        game.pause()
        let elapsed = game.elapsedSeconds
        Thread.sleep(forTimeInterval: 0.02)
        XCTAssertEqual(game.elapsedSeconds, elapsed)
        game.resume()
        XCTAssertLessThan(game.elapsedSeconds - elapsed, 0.01)
    }

    func testFreeTileCacheMatchesReferenceAcrossEveryLevel() {
        let game = GameEngine()
        for level in 1...15 {
            game.startLevel(level)
            XCTAssertEqual(game.freeTileIds(), Set(game.freeTiles().map(\.id)))
            for pair in game.provenSolveOrder {
                game.select(pair.0)
                game.select(pair.1)
            }
            XCTAssertTrue(game.isWon(), "level \(level)")
        }
    }

    func testCurrentHandRiichiDepositPaidToWinnerExactlyOnce() {
        let match = LocalMatch(isHuman: [true, true, true, true])
        defer { match.stop() }
        match.startHand()
        let game = match.engine!
        game.seats[0].hand = waitingHand + ["dR"]
        game.turnDrawnTile = "dR"
        game.seats[0].riichi = true
        game.seats[0].points = 24000
        game.phase = .discard
        match.humanDeclareTsumo()
        XCTAssertEqual(match.points.reduce(0, +), 100000)
        XCTAssertEqual(match.riichiSticksOnTable, 0)
        let settled = match.points
        match.humanDeclareTsumo()
        XCTAssertEqual(match.points, settled)
    }
}
