import XCTest
import Combine
@testable import iVidiMahjong

/// Integration test against a REAL local instance of the Node online server (see
/// Server/). Not part of the normal unit test run -- it needs
/// `PORT=8991 node index.js` already running in Server, and is here purely to
/// verify OnlineClient's message parsing against the actual server protocol rather than
/// assumptions about its shape. Skips itself (not fails) if nothing is listening.
final class OnlineClientIntegrationTests: XCTestCase {

    func testCreateRoomAndStartMatchProducesARealGameState() throws {
        let client = OnlineClient()
        defer { client.disconnect() }
        let connected = expectation(description: "connected")
        var didConnect = false
        client.connect(url: "ws://localhost:8991") { ok in
            didConnect = ok
            connected.fulfill()
        }
        wait(for: [connected], timeout: 5)
        try XCTSkipUnless(didConnect, "local server not running on ws://localhost:8991 -- start Server with PORT=8991 to run this test")

        let joined = expectation(description: "joined room")
        var subscriptions = Set<AnyCancellable>()
        client.$roomCode.dropFirst().first(where: { $0 != nil }).sink { code in
            if code != nil { joined.fulfill() }
        }.store(in: &subscriptions)
        client.createRoom()
        wait(for: [joined], timeout: 5)
        subscriptions.removeAll()

        XCTAssertEqual(client.seat, 0)
        XCTAssertNotNil(client.roomCode)
        XCTAssertEqual(client.roomCode?.count, 5)

        let started = expectation(description: "match started, first state received")
        client.$stateVersion.first(where: { $0 >= 1 }).sink { version in
            if version >= 1 { started.fulfill() }
        }.store(in: &subscriptions)
        client.startMatch()
        wait(for: [started], timeout: 5)
        subscriptions.removeAll()

        let state = try XCTUnwrap(client.state)
        XCTAssertEqual(state["type"] as? String, "state")
        XCTAssertEqual(state["dealerSeat"] as? Int, 0)
        XCTAssertEqual(state["handNumber"] as? Int, 1)
        XCTAssertEqual(state["wallCount"] as? Int, 70)

        let you = try XCTUnwrap(state.dict("you"))
        XCTAssertEqual(you.stringArray("hand").count, 13, "everyone is dealt 13 before the dealer's opening draw")

        let seats = state.dictArray("seats")
        XCTAssertEqual(seats.count, 4)
        XCTAssertEqual(seats[0].bool("isBot"), false, "seat 0 is the connected human")
        XCTAssertEqual(seats[1].bool("isBot"), true)
        XCTAssertEqual(seats[2].bool("isBot"), true)
        XCTAssertEqual(seats[3].bool("isBot"), true)

        let dora = state.stringArray("dora")
        XCTAssertEqual(dora.count, 1)
        XCTAssertNotNil(TILE_TYPES_BY_ID[dora[0]], "dora indicator should be a real tile id")

        client.disconnect()
    }
}
