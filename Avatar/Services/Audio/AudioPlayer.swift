import AVFoundation
import Observation

@Observable
final class AudioPlayer: NSObject, AVAudioPlayerDelegate {
    var isPlaying = false
    var currentAmplitude: Float = 0

    var onPlaybackComplete: (() -> Void)?
    var onAmplitudeUpdate: ((Float) -> Void)?

    private var player: AVAudioPlayer?
    private var amplitudeTimer: Timer?

    func play(data: Data) throws {
        let player = try AVAudioPlayer(data: data)
        player.delegate = self
        player.isMeteringEnabled = true
        player.prepareToPlay()
        player.play()

        self.player = player
        isPlaying = true

        // Update amplitude for lip-sync
        amplitudeTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            guard let self, let player = self.player else { return }
            player.updateMeters()
            let power = player.averagePower(forChannel: 0)
            // Normalize from dB (-160...0) to 0...1
            let normalized = max(0, (power + 50) / 50)
            self.currentAmplitude = normalized
            self.onAmplitudeUpdate?(normalized)
        }
    }

    func playFromURL(_ url: URL) async throws {
        let (data, _) = try await URLSession.shared.data(from: url)
        try play(data: data)
    }

    func stop() {
        player?.stop()
        cleanup()
    }

    private func cleanup() {
        amplitudeTimer?.invalidate()
        amplitudeTimer = nil
        player = nil
        isPlaying = false
        currentAmplitude = 0
    }

    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            self.cleanup()
            self.onPlaybackComplete?()
        }
    }
}
