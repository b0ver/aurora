import Foundation
import AuroraCore
import AuroraCircadian
import AuroraCapture
import AuroraAudio

/// The snapshot of user state we persist across launches.
struct SavedState: Codable {
    var mode: Mode
    var brightness: Double
    var circadian: CircadianSettings
    var installationMethod: InstallationMethod?       // optional for forward/back compat
    var screenSyncSubMode: ScreenSyncSubMode?
    var screenSyncSaturation: Double?
    var musicMode: MusicMode?
    var musicSensitivity: Double?
}

/// Tiny UserDefaults-backed store for `SavedState`.
enum Persistence {
    private static let key = "aurora.state.v1"

    static func load() -> SavedState? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(SavedState.self, from: data)
    }

    static func save(_ state: SavedState) {
        guard let data = try? JSONEncoder().encode(state) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }
}
