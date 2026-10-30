import AVFoundation
import Foundation
#if os(iOS)
import UIKit
#endif

/// Short, original synthesized ceramic taps and chimes. No external audio assets or
/// system alert sounds; players are retained so effects finish after the call returns.
enum SoundManager {
    private static var players: [String: AVAudioPlayer] = [:]

    static var isEnabled: Bool {
        UserDefaults.standard.object(forKey: "ividimahjong-sound-enabled") as? Bool ?? true
    }

    static func tilePick() {
        play("pick", notes: [720], duration: 0.10)
        #if os(iOS)
        if isEnabled { UISelectionFeedbackGenerator().selectionChanged() }
        #endif
    }

    static func match() {
        play("match", notes: [660, 880, 1100], duration: 0.32)
        #if os(iOS)
        if isEnabled { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
        #endif
    }

    static func mismatch() { play("blocked", notes: [240], duration: 0.09) }

    static func win() {
        play("win", notes: [523.25, 659.25, 783.99, 1046.5], duration: 0.65)
        #if os(iOS)
        if isEnabled { UINotificationFeedbackGenerator().notificationOccurred(.success) }
        #endif
    }

    private static func play(_ key: String, notes: [Double], duration: Double) {
        guard isEnabled else { return }
        if players[key] == nil {
            players[key] = try? AVAudioPlayer(data: makeWave(notes: notes, duration: duration))
            players[key]?.volume = 0.35
            players[key]?.prepareToPlay()
        }
        players[key]?.currentTime = 0
        players[key]?.play()
    }

    private static func makeWave(notes: [Double], duration: Double) -> Data {
        let sampleRate = 22050
        let count = Int(Double(sampleRate) * duration)
        var pcm = Data(capacity: count * 2)
        for i in 0..<count {
            let time = Double(i) / Double(sampleRate)
            var value = 0.0
            for (index, frequency) in notes.enumerated() {
                let local = time - Double(index) * 0.045
                guard local >= 0 else { continue }
                let envelope = min(1, local / 0.004) * exp(-local * 12) * min(1, (duration - time) / 0.02)
                value += sin(2 * .pi * frequency * local) * envelope / Double(notes.count)
            }
            var sample = Int16(max(-1, min(1, value * 0.7)) * Double(Int16.max)).littleEndian
            withUnsafeBytes(of: &sample) { pcm.append(contentsOf: $0) }
        }
        var wave = Data()
        func ascii(_ text: String) { wave.append(contentsOf: text.utf8) }
        func u32(_ value: UInt32) {
            var little = value.littleEndian
            withUnsafeBytes(of: &little) { wave.append(contentsOf: $0) }
        }
        func u16(_ value: UInt16) {
            var little = value.littleEndian
            withUnsafeBytes(of: &little) { wave.append(contentsOf: $0) }
        }
        ascii("RIFF"); u32(UInt32(36 + pcm.count)); ascii("WAVEfmt ")
        u32(16); u16(1); u16(1); u32(UInt32(sampleRate)); u32(UInt32(sampleRate * 2)); u16(2); u16(16)
        ascii("data"); u32(UInt32(pcm.count)); wave.append(pcm)
        return wave
    }
}
