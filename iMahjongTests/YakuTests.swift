import XCTest
@testable import iMahjong

final class YakuTests: XCTestCase {

    private func context(winTile: String, winType: WinType = .tsumo, riichi: Bool = false) -> WinContext {
        WinContext(
            concealed: true, openMelds: [], winTile: winTile, winType: winType,
            seatWind: "wE", roundWind: "wE", riichi: riichi, doubleRiichi: false,
            ippatsu: false, haitei: false, houtei: false, rinshan: false, chankan: false,
            doraCount: 0, uraDoraCount: 0
        )
    }

    func testTanyaoIsAwardedForAnAllSimplesHand() throws {
        // 234m 234p 234s 678p, pair 55s -- no terminals (1/9) or honors anywhere.
        let hand = ["m2", "m3", "m4", "p2", "p3", "p4", "p6", "p7", "p8", "s2", "s3", "s4", "s5", "s5"]
        let winCheck = checkWin(hand, [])
        XCTAssertTrue(winCheck.win)

        let result = try XCTUnwrap(bestYakuResult(winCheck, hand, context(winTile: "s5")))
        XCTAssertTrue(result.yakuList.contains { $0.name == "Tanyao" })
    }

    func testTanyaoIsNotAwardedWhenAHandContainsATerminal() throws {
        // Same shape, but 789p instead of 678p pulls in the p9 terminal.
        let hand = ["m2", "m3", "m4", "p2", "p3", "p4", "p7", "p8", "p9", "s2", "s3", "s4", "s5", "s5"]
        let winCheck = checkWin(hand, [])
        XCTAssertTrue(winCheck.win)

        let result = try XCTUnwrap(bestYakuResult(winCheck, hand, context(winTile: "s5")))
        XCTAssertFalse(result.yakuList.contains { $0.name == "Tanyao" })
    }

    func testKokushiIsScoredAsAYakuman() throws {
        let hand = ["m1", "m9", "p1", "p9", "s1", "s9", "wE", "wS", "wW", "wN", "dR", "dG", "dW", "m1"]
        let winCheck = checkWin(hand, [])
        XCTAssertEqual(winCheck.kind, .kokushi)

        let result = try XCTUnwrap(bestYakuResult(winCheck, hand, context(winTile: "m1")))
        XCTAssertTrue(result.yakuman)
    }
}
