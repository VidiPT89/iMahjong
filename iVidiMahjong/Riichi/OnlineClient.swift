import Foundation

/// WebSocket client for the traditional 4-player Riichi online mode. Talks to the
/// authoritative Node server in Server/ (see Server/index.js's protocol comment) -- the
/// server owns all game rules and just pushes down a fully-resolved "state" after every
/// change, so this client is intentionally a thin, mostly untyped relay rather than a second
/// implementation of the rules: messages are decoded with JSONSerialization into
/// `[String: Any]` instead of Codable structs, since the `result` field's shape varies by
/// hand outcome (tsumo/ron/exhaustive) in a way Codable models awkwardly.
final class OnlineClient: ObservableObject {
    @Published var isConnected = false
    @Published var seat: Int?
    @Published var roomCode: String?
    @Published var lobby: [String: Any]?
    @Published var state: [String: Any]?
    /// `state` itself isn't Equatable ([String: Any] can't be), so this ticks up on every
    /// state message purely so SwiftUI's `.onChange` has something comparable to watch —
    /// e.g. to detect "the match just started" and switch screens.
    @Published var stateVersion = 0
    @Published var awaitReactionOpts: [String: Any]?
    @Published var errorMessage: String?
    @Published var connectionLost = false

    private var task: URLSessionWebSocketTask?
    private lazy var session = URLSession(configuration: .ephemeral, delegate: nil, delegateQueue: nil)
    let playerId: String = OnlineClient.loadOrCreatePlayerId()

    private static func loadOrCreatePlayerId() -> String {
        let key = "ividimahjong-player-id"
        if let existing = UserDefaults.standard.string(forKey: key) { return existing }
        let id = "p-" + UUID().uuidString.lowercased()
        UserDefaults.standard.set(id, forKey: key)
        return id
    }

    static func storedServerURL() -> String { UserDefaults.standard.string(forKey: "ividimahjong-server-url") ?? "" }
    static func storeServerURL(_ url: String) { UserDefaults.standard.set(url, forKey: "ividimahjong-server-url") }

    /// Opens the socket and waits for the connection to actually establish (or fail) before
    /// returning, so callers can show a connecting/error state instead of firing messages at
    /// a socket that might never open.
    func connect(url: String, completion: @escaping (Bool) -> Void) {
        disconnect()
        guard let wsURL = URL(string: url.trimmingCharacters(in: .whitespacesAndNewlines)),
              ["ws", "wss"].contains(wsURL.scheme?.lowercased() ?? ""),
              let host = wsURL.host, !host.isEmpty else {
            errorMessage = "invalid-url"
            completion(false)
            return
        }
        var request = URLRequest(url: wsURL)
        request.timeoutInterval = 10
        let socket = session.webSocketTask(with: request)
        task = socket
        socket.resume()
        listen(socket)
        socket.sendPing { [weak self, weak socket] error in
            DispatchQueue.main.async {
                guard let self, let socket, self.task === socket else { return }
                if let error {
                    self.errorMessage = error.localizedDescription
                    self.disconnectSocket()
                    completion(false)
                } else {
                    self.isConnected = true
                    self.connectionLost = false
                    completion(true)
                }
            }
        }
    }

    private func disconnectSocket() {
        let oldTask = task
        task = nil
        oldTask?.cancel(with: .goingAway, reason: nil)
        isConnected = false
    }

    func disconnect() {
        disconnectSocket()
        seat = nil
        roomCode = nil
        lobby = nil
        state = nil
        stateVersion = 0
        awaitReactionOpts = nil
        errorMessage = nil
        connectionLost = false
    }

    func send(_ payload: [String: Any]) {
        guard let socket = task, let data = try? JSONSerialization.data(withJSONObject: payload) else { return }
        socket.send(.data(data)) { [weak self, weak socket] error in
            guard let error else { return }
            DispatchQueue.main.async {
                guard let self, let socket, self.task === socket else { return }
                self.errorMessage = error.localizedDescription
                self.isConnected = false
                self.connectionLost = true
            }
        }
    }

    func createRoom() { send(["type": "create", "playerId": playerId]) }
    func joinRoom(code: String) { send(["type": "join", "code": code, "playerId": playerId]) }
    func startMatch() { send(["type": "start"]) }
    func discard(_ tile: String) { send(["type": "discard", "tile": tile]) }
    func reactPass() { send(["type": "react", "action": "pass"]) }
    func reactRon() { send(["type": "react", "action": "ron"]) }
    func reactPon() { send(["type": "react", "action": "pon"]) }
    func reactKan() { send(["type": "react", "action": "kan"]) }
    func reactChi(_ pair: [String]) { send(["type": "react", "action": ["chi": pair]]) }
    func declareRiichi() { send(["type": "riichi"]) }
    func declareTsumo() { send(["type": "tsumo"]) }
    func ankan(tileType: String) { send(["type": "ankan", "tileType": tileType]) }
    func nextHand() { send(["type": "nextHand"]) }

    private func listen(_ socket: URLSessionWebSocketTask) {
        socket.receive { [weak self, weak socket] result in
            DispatchQueue.main.async {
                guard let self, let socket, self.task === socket else { return }
                switch result {
                case .failure:
                    self.isConnected = false
                    self.connectionLost = true
                    return
                case .success(let message):
                    let data: Data?
                    switch message {
                    case .data(let value): data = value
                    case .string(let value): data = value.data(using: .utf8)
                    @unknown default: data = nil
                    }
                    if let data, let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                        self.handle(object)
                    }
                    self.listen(socket)
                }
            }
        }
    }

    private func handle(_ msg: [String: Any]) {
        guard let type = msg["type"] as? String else { return }
        switch type {
        case "joined":
            seat = msg["seat"] as? Int
            roomCode = msg["code"] as? String
        case "error":
            errorMessage = msg["message"] as? String
        case "lobby":
            lobby = msg
        case "state":
            state = msg
            stateVersion += 1
            awaitReactionOpts = msg.dict("reactionOptions")
        case "awaitReaction":
            if (msg["seat"] as? Int) == seat { awaitReactionOpts = msg["opts"] as? [String: Any] }
        default:
            break
        }
    }
}

// MARK: - Small helpers for reading the loosely-typed state/lobby dictionaries

extension Dictionary where Key == String, Value == Any {
    func str(_ key: String) -> String? { self[key] as? String }
    func int(_ key: String) -> Int? { self[key] as? Int }
    func bool(_ key: String) -> Bool? { self[key] as? Bool }
    func dict(_ key: String) -> [String: Any]? { self[key] as? [String: Any] }
    func array(_ key: String) -> [Any]? { self[key] as? [Any] }
    func dictArray(_ key: String) -> [[String: Any]] { (self[key] as? [[String: Any]]) ?? [] }
    func stringArray(_ key: String) -> [String] { (self[key] as? [String]) ?? [] }
}
