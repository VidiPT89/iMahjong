import XCTest
@testable import iMahjong

final class HandEvalTests: XCTestCase {

    func testStandardFourSetsPlusPairIsAWin() {
        // 234m 234p 234s 678p, pair 55s -- 4 sequences + a pair, 14 tiles, no melds.
        let hand = ["m2", "m3", "m4", "p2", "p3", "p4", "p6", "p7", "p8", "s2", "s3", "s4", "s5", "s5"]
        let result = checkWin(hand, [])
        XCTAssertTrue(result.win)
        XCTAssertEqual(result.kind, .standard)
        XCTAssertFalse(result.decompositions.isEmpty)
    }

    func testSevenDistinctPairsIsChiitoitsu() {
        let hand = ["m1", "m1", "m3", "m3", "p5", "p5", "s7", "s7", "wE", "wE", "dR", "dR", "m9", "m9"]
        let result = checkWin(hand, [])
        XCTAssertTrue(result.win)
        XCTAssertEqual(result.kind, .chiitoitsu)
    }

    func testThirteenOrphansIsKokushi() {
        let hand = ["m1", "m9", "p1", "p9", "s1", "s9", "wE", "wS", "wW", "wN", "dR", "dG", "dW", "m1"]
        XCTAssertTrue(isKokushiMusou(hand))
        let result = checkWin(hand, [])
        XCTAssertEqual(result.kind, .kokushi)
    }

    func testAnIncompleteHandIsNotAWin() {
        // Same shape as the standard-win test but with the pair broken (single m9 instead
        // of a second s5), so no valid 4-sets-plus-pair decomposition exists.
        let hand = ["m2", "m3", "m4", "p2", "p3", "p4", "p6", "p7", "p8", "s2", "s3", "s4", "s5", "m9"]
        let result = checkWin(hand, [])
        XCTAssertFalse(result.win)
    }
}
