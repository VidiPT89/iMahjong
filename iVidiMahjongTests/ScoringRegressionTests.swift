import XCTest
@testable import iVidiMahjong

final class ScoringRegressionTests: XCTestCase {
    private func score(_ hand: [String], tile: String, type: WinType = .tsumo) throws -> YakuResult {
        let context = WinContext(concealed: true, openMelds: [], winTile: tile, winType: type,
                                 seatWind: "wE", roundWind: "wE", riichi: false, doubleRiichi: false,
                                 ippatsu: false, haitei: false, houtei: false, rinshan: false,
                                 doraCount: 0, uraDoraCount: 0)
        return try XCTUnwrap(bestYakuResult(checkWin(hand, []), hand, context))
    }

    func testSevenPairsCombinesWithTanyaoAndSelfDraw() throws {
        let hand = ["m2", "m2", "m4", "m4", "p3", "p3", "p5", "p5", "s2", "s2", "s6", "s6", "s8", "s8"]
        let result = try score(hand, tile: "s8")
        XCTAssertEqual(Set(result.yakuList.map(\.name)), ["Chiitoitsu", "Tanyao", "Menzen Tsumo"])
        XCTAssertEqual(result.fu, 25)
    }

    func testSanshokuDoesNotRequireAllFourSetsToBeSequences() throws {
        let hand = ["m2", "m3", "m4", "p2", "p3", "p4", "s2", "s3", "s4", "wE", "wE", "wE", "dR", "dR"]
        XCTAssertTrue(try score(hand, tile: "dR").yakuList.contains { $0.name == "Sanshoku Doujun" })
    }

    func testRonCompletedTripletIsNotSuuankou() throws {
        let hand = ["m2", "m2", "m2", "p3", "p3", "p3", "s4", "s4", "s4", "wE", "wE", "wE", "dR", "dR"]
        let result = try score(hand, tile: "m2", type: .ron)
        XCTAssertFalse(result.yakuman)
        XCTAssertTrue(result.yakuList.contains { $0.name == "Sanankou" })
        XCTAssertTrue(try score(hand, tile: "dR", type: .ron).yakuList.contains { $0.name == "Suuankou" })
    }

    func testSevenEightNineWaitingOnSevenIsNotPinfu() throws {
        let hand = ["m7", "m8", "m9", "p1", "p2", "p3", "s1", "s2", "s3", "s4", "s5", "s6", "p5", "p5"]
        let result = try score(hand, tile: "m7")
        XCTAssertFalse(result.yakuList.contains { $0.name == "Pinfu" })
        XCTAssertEqual(result.fu, 30)
        XCTAssertTrue(try score(hand, tile: "m9").yakuList.contains { $0.name == "Pinfu" })
    }

    func testValuePairPreventsPinfuFuShortcut() throws {
        let hand = ["m1", "m2", "m3", "p2", "p3", "p4", "s1", "s2", "s3", "s4", "s5", "s6", "dR", "dR"]
        let result = try score(hand, tile: "p4")
        XCTAssertFalse(result.yakuList.contains { $0.name == "Pinfu" })
        XCTAssertEqual(result.fu, 30)
    }
}
