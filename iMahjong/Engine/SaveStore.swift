import Foundation

enum SaveStore {
    private static let key = "imahjong-save"

    static func save(_ engine: GameEngine) {
        guard let data = try? JSONEncoder().encode(engine.makeSnapshot()) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }

    static func load() -> GameSnapshot? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(GameSnapshot.self, from: data)
    }

    static func hasSave() -> Bool {
        UserDefaults.standard.data(forKey: key) != nil
    }

    static func clear() {
        UserDefaults.standard.removeObject(forKey: key)
    }
}
