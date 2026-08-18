import Foundation

/// Local, backend-free leaderboard for Solitaire: best (lowest) elapsed time and best
/// (fewest) moves, tracked independently per difficulty. Persisted with UserDefaults +
/// Codable, following the exact same pattern as SaveStore (see SaveStore.swift) rather
/// than introducing a new persistence mechanism.
struct LeaderboardEntry: Codable, Equatable {
    var bestTimeSeconds: Double?
    var bestMoves: Int?
}

enum Leaderboard {
    private static let key = "imahjong-leaderboard"

    private static func loadAll() -> [String: LeaderboardEntry] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode([String: LeaderboardEntry].self, from: data)
        else { return [:] }
        return decoded
    }

    private static func saveAll(_ entries: [String: LeaderboardEntry]) {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }

    static func entry(for difficulty: Difficulty) -> LeaderboardEntry {
        loadAll()[difficulty.rawValue] ?? LeaderboardEntry()
    }

    /// Records a completed game, keeping whichever of the previous best / new result is
    /// better for each metric independently (a win can improve the time record, the moves
    /// record, both, or neither). Returns the entry after the update plus whether each
    /// metric was a new record, for UI ("New Best!" badges).
    @discardableResult
    static func recordWin(difficulty: Difficulty, timeSeconds: Double, moves: Int) -> (entry: LeaderboardEntry, newBestTime: Bool, newBestMoves: Bool) {
        var all = loadAll()
        var current = all[difficulty.rawValue] ?? LeaderboardEntry()

        var newBestTime = false
        if current.bestTimeSeconds == nil || timeSeconds < current.bestTimeSeconds! {
            current.bestTimeSeconds = timeSeconds
            newBestTime = true
        }

        var newBestMoves = false
        if current.bestMoves == nil || moves < current.bestMoves! {
            current.bestMoves = moves
            newBestMoves = true
        }

        all[difficulty.rawValue] = current
        saveAll(all)
        return (current, newBestTime, newBestMoves)
    }

    static func clear() {
        UserDefaults.standard.removeObject(forKey: key)
    }
}
