import Foundation
import Combine

struct RefPosition {
    let refId: Int
    let x: Int
    let y: Int
    let z: Int
}

struct UnpairableBoardError: Error {}

/// Given a list of {refId, x, y, z} positions, returns an ordered list of
/// (refIdA, refIdB) pairs such that each pair was mutually free — not
/// covered, and open on at least one side — at the moment it was paired,
/// considering only the positions not yet paired earlier in the list.
///
/// Why this guarantees a solvable board: geometric freeness (covered /
/// open-side) depends only on which POSITIONS are still occupied, never on
/// tile type. So once a matching tile type is assigned to each pair here,
/// playing the pairs back in this exact order reproduces this same legal
/// removal sequence on the real board.
///
/// Each round collects every currently-free position and pairs them off two
/// at a time; a leftover odd one just stays free (freeness only grows as
/// other tiles are removed) and joins next round's pairing.
func computeSolvablePairing(_ positions: [RefPosition]) throws -> [(Int, Int)] {
    var remaining: [Int: RefPosition] = Dictionary(uniqueKeysWithValues: positions.map { ($0.refId, $0) })
    var pairs: [(Int, Int)] = []

    func isCovered(_ p: RefPosition) -> Bool {
        remaining.values.contains { $0.refId != p.refId && $0.x == p.x && $0.y == p.y && $0.z > p.z }
    }
    func isOpenSide(_ p: RefPosition, _ dx: Int) -> Bool {
        !remaining.values.contains { $0.refId != p.refId && $0.z == p.z && $0.y == p.y && $0.x == p.x + dx }
    }
    func isFree(_ p: RefPosition) -> Bool {
        !isCovered(p) && (isOpenSide(p, -1) || isOpenSide(p, 1))
    }

    while !remaining.isEmpty {
        var free = remaining.values.filter(isFree)
        if free.count < 2 {
            throw UnpairableBoardError()
        }
        free.shuffle() // which tiles get paired (not just which are free) affects future rounds
        var i = 0
        while i + 1 < free.count {
            pairs.append((free[i].refId, free[i + 1].refId))
            remaining.removeValue(forKey: free[i].refId)
            remaining.removeValue(forKey: free[i + 1].refId)
            i += 2
        }
        // An odd one out (if any) simply stays in `remaining` — it's still free
        // next round by construction, so the loop always makes progress.
    }
    return pairs
}

/// computeSolvablePairing occasionally paints itself into a corner depending
/// on which free tiles get grouped together early on; retrying re-rolls that
/// choice until a full reduction succeeds.
func computeSolvablePairingWithRetry(_ positions: [RefPosition], maxAttempts: Int = 200) throws -> [(Int, Int)] {
    var lastError: Error = UnpairableBoardError()
    for _ in 0..<maxAttempts {
        do {
            return try computeSolvablePairing(positions)
        } catch {
            lastError = error
        }
    }
    throw lastError
}

enum SelectResult {
    case ignored
    case blocked(GameTile)
    case selected(GameTile)
    case deselected(GameTile)
    case matched(a: GameTile, b: GameTile, won: Bool)
    case mismatch(previous: GameTile, tile: GameTile)
}

final class GameEngine: ObservableObject {
    @Published private(set) var tiles: [GameTile] = []
    @Published private(set) var selectedId: Int?
    private(set) var history: [(a: Int, b: Int)] = []
    @Published private(set) var moves = 0
    @Published private(set) var hintsUsed = 0
    private(set) var startedAt = Date()
    /// The construction-time pairing order used to guarantee solvability — kept for
    /// solvability testing, not used by normal gameplay (which lets the player pick
    /// any legal pair, not just this one).
    private(set) var provenSolveOrder: [(Int, Int)] = []
    private(set) var difficulty: Difficulty

    /// Only meaningful for `.infinite`: the level currently being played, driving the board
    /// size via buildInfiniteLayout. Ignored for the fixed difficulties.
    @Published private(set) var level = 1

    init(difficulty: Difficulty = .medium) {
        self.difficulty = difficulty
        reset()
    }

    func reset(difficulty newDifficulty: Difficulty? = nil) {
        if let newDifficulty { difficulty = newDifficulty }
        level = 1
        let layout = difficulty.layout ?? buildInfiniteLayout(1)
        tiles = layout.enumerated().map { i, pos in
            GameTile(id: i, x: pos.x, y: pos.y, z: pos.z, removed: false, typeId: nil)
        }

        let refPositions = tiles.map { RefPosition(refId: $0.id, x: $0.x, y: $0.y, z: $0.z) }
        guard let pairing = try? computeSolvablePairingWithRetry(refPositions) else {
            fatalError("Could not compute a solvable pairing for the turtle layout")
        }
        let units = difficulty == .infinite ? buildInfinitePairUnits(totalTiles: tiles.count) : buildPairUnits(for: difficulty)

        for (idx, pair) in pairing.enumerated() {
            let (typeA, typeB) = units[idx]
            setTypeId(typeA, forTileId: pair.0)
            setTypeId(typeB, forTileId: pair.1)
        }
        provenSolveOrder = pairing

        selectedId = nil
        history = []
        moves = 0
        hintsUsed = 0
        startedAt = Date()
    }

    /// Infinite mode only: deals the next (bigger) level's board in place, keeping the run's
    /// cumulative moves/score/timer going rather than resetting them like `reset` does for a
    /// brand new game. The undo history does reset — undoing across a level boundary back
    /// into an already-cleared board doesn't make sense.
    func dealNextInfiniteLevel() {
        level += 1
        let layout = buildInfiniteLayout(level)
        tiles = layout.enumerated().map { i, pos in
            GameTile(id: i, x: pos.x, y: pos.y, z: pos.z, removed: false, typeId: nil)
        }

        let refPositions = tiles.map { RefPosition(refId: $0.id, x: $0.x, y: $0.y, z: $0.z) }
        guard let pairing = try? computeSolvablePairingWithRetry(refPositions) else {
            fatalError("Could not compute a solvable pairing for the infinite layout")
        }
        let units = buildInfinitePairUnits(totalTiles: tiles.count)

        for (idx, pair) in pairing.enumerated() {
            let (typeA, typeB) = units[idx]
            setTypeId(typeA, forTileId: pair.0)
            setTypeId(typeB, forTileId: pair.1)
        }
        provenSolveOrder = pairing

        selectedId = nil
        history = []
    }

    private func setTypeId(_ typeId: String, forTileId id: Int) {
        if let idx = tiles.firstIndex(where: { $0.id == id }) {
            tiles[idx].typeId = typeId
        }
    }

    func getTile(_ id: Int) -> GameTile? {
        tiles.first { $0.id == id }
    }

    func active() -> [GameTile] {
        tiles.filter { !$0.removed }
    }

    func remaining() -> Int {
        active().count
    }

    func isCovered(_ tile: GameTile) -> Bool {
        tiles.contains { !$0.removed && $0.x == tile.x && $0.y == tile.y && $0.z > tile.z }
    }

    func isOpenLeft(_ tile: GameTile) -> Bool {
        !tiles.contains { !$0.removed && $0.z == tile.z && $0.y == tile.y && $0.x == tile.x - 1 }
    }

    func isOpenRight(_ tile: GameTile) -> Bool {
        !tiles.contains { !$0.removed && $0.z == tile.z && $0.y == tile.y && $0.x == tile.x + 1 }
    }

    func isFree(_ tile: GameTile) -> Bool {
        if tile.removed { return false }
        if isCovered(tile) { return false }
        return isOpenLeft(tile) || isOpenRight(tile)
    }

    func freeTiles() -> [GameTile] {
        active().filter(isFree)
    }

    /// Attempts to select a tile; returns what happened so the UI can animate/react.
    @discardableResult
    func select(_ id: Int) -> SelectResult {
        guard let tile = getTile(id), !tile.removed else { return .ignored }
        if !isFree(tile) { return .blocked(tile) }

        if selectedId == id {
            selectedId = nil
            return .deselected(tile)
        }

        if selectedId == nil {
            selectedId = id
            return .selected(tile)
        }

        guard let first = getTile(selectedId!) else {
            selectedId = id
            return .selected(tile)
        }

        if tilesMatch(first.typeId ?? "", tile.typeId ?? "") {
            markRemoved(first.id)
            markRemoved(tile.id)
            selectedId = nil
            moves += 1
            history.append((a: first.id, b: tile.id))
            return .matched(a: first, b: tile, won: remaining() == 0)
        }

        selectedId = id
        return .mismatch(previous: first, tile: tile)
    }

    private func markRemoved(_ id: Int) {
        if let idx = tiles.firstIndex(where: { $0.id == id }) {
            tiles[idx].removed = true
        }
    }

    private func markRestored(_ id: Int) {
        if let idx = tiles.firstIndex(where: { $0.id == id }) {
            tiles[idx].removed = false
        }
    }

    @discardableResult
    func undo() -> (a: GameTile, b: GameTile)? {
        guard let last = history.popLast() else { return nil }
        markRestored(last.a)
        markRestored(last.b)
        selectedId = nil
        moves += 1
        return (getTile(last.a)!, getTile(last.b)!)
    }

    /// Finds one legal matching pair among currently free tiles, for the hint button.
    func findHint() -> (GameTile, GameTile)? {
        let free = freeTiles()
        for i in 0..<free.count {
            for j in (i + 1)..<free.count {
                if tilesMatch(free[i].typeId ?? "", free[j].typeId ?? "") {
                    return (free[i], free[j])
                }
            }
        }
        return nil
    }

    func useHint() {
        hintsUsed += 1
    }

    func hasAvailableMove() -> Bool {
        findHint() != nil
    }

    func isWon() -> Bool {
        remaining() == 0
    }

    func isStuck() -> Bool {
        !isWon() && !hasAvailableMove()
    }

    /// Reassigns tile types on the tiles still on the board (same positions), using the
    /// same simultaneous-freeness pairing as the initial deal, so the remaining board is
    /// always solvable again after a reshuffle.
    func reshuffle() -> Bool {
        let remainingTiles = active()
        let refPositions = remainingTiles.map { RefPosition(refId: $0.id, x: $0.x, y: $0.y, z: $0.z) }
        guard let pairing = try? computeSolvablePairingWithRetry(refPositions) else { return false }

        var typeCounts: [String: Int] = [:]
        for t in remainingTiles { typeCounts[t.typeId ?? "", default: 0] += 1 }
        let units = buildPairUnitsFromInventory(typeCounts)

        for (idx, pair) in pairing.enumerated() {
            let (typeA, typeB) = units[idx]
            setTypeId(typeA, forTileId: pair.0)
            setTypeId(typeB, forTileId: pair.1)
        }
        provenSolveOrder = pairing

        selectedId = nil
        return true
    }

    var elapsedSeconds: TimeInterval {
        Date().timeIntervalSince(startedAt)
    }

    func makeSnapshot() -> GameSnapshot {
        GameSnapshot(
            difficulty: difficulty.rawValue,
            tiles: tiles,
            selectedId: selectedId,
            historyPairs: history.map { [$0.a, $0.b] },
            moves: moves,
            hintsUsed: hintsUsed,
            elapsedSeconds: elapsedSeconds,
            level: level
        )
    }

    func restore(from snapshot: GameSnapshot) {
        difficulty = Difficulty(rawValue: snapshot.difficulty) ?? .medium
        level = snapshot.level
        tiles = snapshot.tiles
        selectedId = snapshot.selectedId
        history = snapshot.historyPairs.map { (a: $0[0], b: $0[1]) }
        moves = snapshot.moves
        hintsUsed = snapshot.hintsUsed
        startedAt = Date().addingTimeInterval(-snapshot.elapsedSeconds)
        provenSolveOrder = []
    }
}

struct GameSnapshot: Codable {
    var difficulty: String
    var tiles: [GameTile]
    var selectedId: Int?
    var historyPairs: [[Int]]
    var moves: Int
    var hintsUsed: Int
    var elapsedSeconds: Double
    var level: Int = 1
}
