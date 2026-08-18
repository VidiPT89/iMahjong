import AudioToolbox

/// Sound feedback for tile pick / match / mismatch / win.
///
/// PLACEHOLDER NOTE: the project ships no custom audio assets (no Sounds/Resources folder,
/// no .mp3/.wav/.caf files) — see the search performed before adding this file. Rather than
/// invent binary assets, this uses AudioToolbox's built-in system sounds via
/// `AudioServicesPlaySystemSound`, which works identically on iOS and macOS with zero
/// bundled resources. If/when real sound design assets are added to the project (e.g. under
/// iMahjong/Sounds/*.caf), swap this implementation for AVFoundation's `AVAudioPlayer`
/// (load each .caf/.wav via Bundle.main.url(forResource:withExtension:), keep one
/// AVAudioPlayer per effect alive for low-latency replay) — the call sites in GameView
/// (SoundManager.pick/match/mismatch/win) would not need to change.
enum SoundManager {
    /// System sound IDs are OS-provided short UI sounds; picked here only as stand-ins for
    /// the real effect they name (a soft tick, a pleasant chime, a low buzz, a fanfare).
    private enum SystemSoundID_: UInt32 {
        case tilePick = 1104   // "Tock" — short, unobtrusive tap
        case match = 1111      // short positive click
        case mismatch = 1053   // low negative buzz
        case win = 1025        // more elaborate multi-tone sound
    }

    static var isEnabled = true

    static func tilePick() { play(.tilePick) }
    static func match() { play(.match) }
    static func mismatch() { play(.mismatch) }
    static func win() { play(.win) }

    private static func play(_ sound: SystemSoundID_) {
        guard isEnabled else { return }
        AudioServicesPlaySystemSound(SystemSoundID(sound.rawValue))
    }
}
