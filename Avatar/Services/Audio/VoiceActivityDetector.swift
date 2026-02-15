import Foundation

final class VoiceActivityDetector {
    var onSilenceDetected: (() -> Void)?

    private let silenceThreshold: Float
    private let silenceDuration: TimeInterval
    /// Minimum time before silence detection is allowed (prevents premature cutoff)
    private let minimumRecordingDuration: TimeInterval
    private var lastSpeechTime: Date?
    private var recordingStartTime: Date?
    private var timer: Timer?

    init(silenceThreshold: Float = 0.01, silenceDuration: TimeInterval = 1.5, minimumRecordingDuration: TimeInterval = 1.0) {
        self.silenceThreshold = silenceThreshold
        self.silenceDuration = silenceDuration
        self.minimumRecordingDuration = minimumRecordingDuration
    }

    func start() {
        lastSpeechTime = Date()
        recordingStartTime = Date()
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
        recordingStartTime = nil
    }

    private func checkSilence() {
        guard let lastSpeech = lastSpeechTime,
              let startTime = recordingStartTime else { return }

        // Don't trigger silence detection until minimum recording time has passed
        let elapsed = Date().timeIntervalSince(startTime)
        guard elapsed >= minimumRecordingDuration else { return }

        if Date().timeIntervalSince(lastSpeech) > silenceDuration {
            stop()
            onSilenceDetected?()
        }
    }
}
