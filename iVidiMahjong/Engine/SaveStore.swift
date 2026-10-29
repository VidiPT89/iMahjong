import Foundation

enum SaveStore {
    private static let key = "imahjong-save"

    static func save(_ engine: GameEngine) {
        if engine.isWon() && (engine.difficulty != .infinite || engine.level >= LEVELS_MAX_LEVEL) {
            clear()
            return
        }
        guard let data = try? JSONEncoder().encode(engine.makeSnapshot()) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }

    static func load() -> GameSnapshot? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        guard let snapshot = try? JSONDecoder().decode(GameSnapshot.self, from: data), snapshot.isValid else { return nil }
        return snapshot
    }

    static func hasSave() -> Bool {
        load() != nil
    }

    static func clear() {
        UserDefaults.standard.removeObject(forKey: key)
    }
}
