import Foundation

final class VoiceActivityDetector {
    var onSilenceDetected: (() -> Void)?

    private let silenceThreshold: Float
    private let silenceDuration: TimeInterval
    private var lastSpeechTime: Date?
    private var timer: Timer?

    init(silenceThreshold: Float = 0.01, silenceDuration: TimeInterval = 0.8) {
        self.silenceThreshold = silenceThreshold
        self.silenceDuration = silenceDuration
    }

    func start() {
        lastSpeechTime = Date()
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.checkSilence()
        }
    }

    func processAmplitude(_ amplitude: Float) {
        if amplitude > silenceThreshold {
            lastSpeechTime = Date()
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        lastSpeechTime = nil
    }

    private func checkSilence() {
        guard let lastSpeech = lastSpeechTime else { return }
        if Date().timeIntervalSince(lastSpeech) > silenceDuration {
            stop()
            onSilenceDetected?()
        }
    }
}
