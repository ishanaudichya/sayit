import AVFoundation
import AppKit

/// Plays SayIt's synthesized UI sounds (see scripts/make_sounds.swift) and
/// trackpad haptics. Everything is preloaded at startup so the Fn-down flick
/// has zero perceptible latency.
@MainActor
final class SoundPlayer {
    static let shared = SoundPlayer()

    enum Effect: String, CaseIterable {
        case start, stop, success, error
    }

    private var players: [Effect: AVAudioPlayer] = [:]

    private init() {
        for effect in Effect.allCases {
            guard let url = Bundle.main.url(forResource: effect.rawValue, withExtension: "wav") else {
                NSLog("SayIt: missing sound asset \(effect.rawValue).wav")
                continue
            }
            if let player = try? AVAudioPlayer(contentsOf: url) {
                player.volume = 0.85
                player.prepareToPlay()
                players[effect] = player
            }
        }
    }

    func play(_ effect: Effect) {
        guard UserDefaults.standard.bool(forKey: "soundsEnabled") else { return }
        guard let player = players[effect] else { return }
        player.currentTime = 0
        player.play()
    }

    func haptic(_ pattern: NSHapticFeedbackManager.FeedbackPattern = .generic) {
        guard UserDefaults.standard.bool(forKey: "hapticsEnabled") else { return }
        NSHapticFeedbackManager.defaultPerformer.perform(pattern, performanceTime: .now)
    }
}
