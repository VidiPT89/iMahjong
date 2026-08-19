import XCTest
@testable import iMahjong

final class GameEngineTests: XCTestCase {

    /// "Provably solvable" means there EXISTS a clearing order — the one `reset()` computed
    /// and stashed on `provenSolveOrder` by walking a full reduction backwards — not that
    /// any order a player picks will clear the board. Replaying that exact order is the
    /// actual proof.
    func testFreshBoardIsSolvableInItsOwnProvenOrder() throws {
        for difficulty in Difficulty.allCases {
            let engine = GameEngine(difficulty: difficulty)
            let totalTiles = engine.tiles.count
            XCTAssertGreaterThan(totalTiles, 0, "\(difficulty) board should have tiles")
            XCTAssertEqual(engine.provenSolveOrder.count, totalTiles / 2)

            for (a, b) in engine.provenSolveOrder {
                guard case .selected = engine.select(a) else {
                    return XCTFail("expected \(a) to be selectable")
                }
                guard case .matched = engine.select(b) else {
                    return XCTFail("expected \(b) to match the previous selection")
                }
            }

            XCTAssertEqual(engine.remaining(), 0)
            XCTAssertEqual(engine.moves, totalTiles / 2)
        }
    }

    func testEveryFreshBoardStartsWithALegalMove() {
        for difficulty in Difficulty.allCases {
            let engine = GameEngine(difficulty: difficulty)
            XCTAssertNotNil(engine.findHint(), "\(difficulty) board should not start stuck")
            XCTAssertFalse(engine.isStuck())
        }
    }

    func testSelectingACoveredOrBoxedInTileIsBlocked() {
        let engine = GameEngine(difficulty: .medium)
        guard let blocked = engine.tiles.first(where: { !engine.isFree($0) }) else {
            return XCTFail("expected at least one non-free tile on a fresh medium board")
        }
        guard case .blocked = engine.select(blocked.id) else {
            return XCTFail("expected a blocked result")
        }
    }

    func testMismatchedFreeTilesAreNotRemoved() {
        let engine = GameEngine(difficulty: .medium)
        let free = engine.freeTiles()
        guard let a = free.first, let b = free.first(where: { $0.typeId != a.typeId }) else {
            return XCTFail("expected two free tiles of different types on a fresh board")
        }

        guard case .selected = engine.select(a.id) else { return XCTFail("expected selection") }
        guard case .mismatch = engine.select(b.id) else { return XCTFail("expected a mismatch") }

        XCTAssertFalse(engine.getTile(a.id)!.removed)
        XCTAssertFalse(engine.getTile(b.id)!.removed)
    }

    func testReshuffleKeepsRemainingCountAndStaysSolvable() {
        let engine = GameEngine(difficulty: .medium)
        let (a, b) = engine.provenSolveOrder[0]
        _ = engine.select(a)
        _ = engine.select(b)
        let remainingBefore = engine.remaining()

        XCTAssertTrue(engine.reshuffle())
        XCTAssertEqual(engine.remaining(), remainingBefore)
        XCTAssertNotNil(engine.findHint())
    }
}
