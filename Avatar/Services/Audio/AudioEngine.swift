import Foundation
import Observation

@Observable
final class AudioEngine {
    enum State: Equatable {
        case idle
        case listening
        case processing
        case playingResponse
    }

    var state: State = .idle
    var recordingAmplitude: Float = 0
    var playbackAmplitude: Float = 0

    let recorder = AudioRecorder()
    let player = AudioPlayer()
    let vad = VoiceActivityDetector()

    var onAudioChunkReady: ((Data) -> Void)?
    var onRecordingFinished: (() -> Void)?

    init() {
        setupCallbacks()
    }

    private func setupCallbacks() {
        recorder.onAudioChunk = { [weak self] chunk in
            guard let self else { return }
            self.recordingAmplitude = self.recorder.currentAmplitude
            self.vad.processAmplitude(self.recorder.currentAmplitude)
            self.onAudioChunkReady?(chunk)
        }

        vad.onSilenceDetected = { [weak self] in
            self?.stopListening()
        }

        player.onAmplitudeUpdate = { [weak self] amplitude in
            self?.playbackAmplitude = amplitude
        }

        player.onPlaybackComplete = { [weak self] in
            self?.state = .idle
            self?.playbackAmplitude = 0
        }
    }

    func startListening() {
        guard state == .idle else { return }
        do {
            try AudioSessionManager.shared.configureForConversation()
            try recorder.startRecording()
            vad.start()
            state = .listening
        } catch {
            state = .idle
        }
    }

    func stopListening() {
        guard state == .listening else { return }
        recorder.stopRecording()
        vad.stop()
        state = .processing
        recordingAmplitude = 0
        onRecordingFinished?()
    }

    func playResponse(data: Data, emotion: Emotion) {
        state = .playingResponse
        do {
            try player.play(data: data)
        } catch {
            state = .idle
        }
    }

    func playResponseFromURL(_ url: URL, emotion: Emotion) {
        state = .playingResponse
        Task {
            do {
                try await player.playFromURL(url)
            } catch {
                state = .idle
            }
        }
    }

    func reset() {
        recorder.stopRecording()
        vad.stop()
        player.stop()
        state = .idle
        recordingAmplitude = 0
        playbackAmplitude = 0
    }
}
