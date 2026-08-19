import XCTest
@testable import iMahjong

final class InfiniteModeTests: XCTestCase {

    /// "Provably solvable" means there EXISTS a clearing order — the one stashed on
    /// `provenSolveOrder` — not that any order a player picks will clear the board.
    /// Replaying that exact order is the actual proof, same as GameEngineTests.
    func testInfiniteBoardIsSolvableInItsOwnProvenOrderAcrossLevels() throws {
        for level in [1, 3, 8] {
            let engine = GameEngine(difficulty: .infinite)
            for _ in 1..<level { engine.dealNextInfiniteLevel() }

            let totalTiles = engine.tiles.count
            XCTAssertEqual(engine.provenSolveOrder.count, totalTiles / 2)

            for (a, b) in engine.provenSolveOrder {
                guard case .selected = engine.select(a) else {
                    return XCTFail("expected \(a) to be selectable at level \(level)")
                }
                guard case .matched = engine.select(b) else {
                    return XCTFail("expected \(b) to match at level \(level)")
                }
            }

            XCTAssertEqual(engine.remaining(), 0)
        }
    }

    func testBoardGrowsAndStaysEvenAcrossLevels() {
        let engine = GameEngine(difficulty: .infinite)
        var previousCount = engine.tiles.count
        XCTAssertEqual(previousCount % 2, 0)

        for _ in 0..<11 {
            engine.dealNextInfiniteLevel()
            XCTAssertEqual(engine.tiles.count % 2, 0)
            XCTAssertGreaterThanOrEqual(engine.tiles.count, previousCount, "level \(engine.level) should not shrink")
            previousCount = engine.tiles.count
        }
    }

    func testDealNextInfiniteLevelAdvancesLevelWithoutResettingMoves() {
        let engine = GameEngine(difficulty: .infinite)
        XCTAssertEqual(engine.level, 1)

        let (a, b) = engine.provenSolveOrder[0]
        _ = engine.select(a)
        _ = engine.select(b)
        XCTAssertEqual(engine.moves, 1)

        engine.dealNextInfiniteLevel()

        XCTAssertEqual(engine.level, 2)
        XCTAssertEqual(engine.moves, 1)
        XCTAssertEqual(engine.remaining(), engine.tiles.count)
    }
}
