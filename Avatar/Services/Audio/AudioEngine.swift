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
    /// Fires when TTS audio duration is known (after playback starts)
    var onAudioDurationReady: ((TimeInterval) -> Void)?
    /// Fires when TTS audio playback finishes
    var onPlaybackComplete: (() -> Void)?

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
            self?.onPlaybackComplete?()
        }

        player.onDurationReady = { [weak self] duration in
            self?.onAudioDurationReady?(duration)
        }
    }

    func startListening() {
        guard state == .idle else { return }
        do {
            try AudioSessionManager.shared.configureForConversation()
            try recorder.startRecording()
            vad.start()
            state = .listening
            print("AudioEngine: Started listening")
        } catch {
            print("AudioEngine: Failed to start listening: \(error)")
            state = .idle
        }
    }

    func stopListening() {
        guard state == .listening else { return }
        recorder.stopRecording()
        vad.stop()
        state = .processing
        recordingAmplitude = 0
        print("AudioEngine: Stopped listening, sending audio")
        onRecordingFinished?()
    }

    func playResponse(data: Data, emotion: Emotion) {
        state = .playingResponse
        print("AudioEngine: Playing inline audio data, size=\(data.count)")
        do {
            try AudioSessionManager.shared.configureForConversation()
            try player.play(data: data)
            print("AudioEngine: Inline audio playback started successfully")
        } catch {
            print("AudioEngine: Failed to play response data: \(error)")
            state = .idle
        }
    }

    func playResponseFromURL(_ url: URL, emotion: Emotion) {
        state = .playingResponse
        print("AudioEngine: Playing TTS from URL: \(url)")
        Task {
            do {
                // Configure audio session for speaker playback BEFORE downloading
                try AudioSessionManager.shared.configureForConversation()

                let (data, response) = try await URLSession.shared.data(from: url)
                let httpResponse = response as? HTTPURLResponse
                let statusCode = httpResponse?.statusCode ?? -1
                print("AudioEngine: Downloaded TTS audio, size=\(data.count), status=\(statusCode), contentType=\(httpResponse?.value(forHTTPHeaderField: "Content-Type") ?? "unknown")")

                guard statusCode == 200 else {
                    print("AudioEngine: TTS download failed with status \(statusCode)")
                    await MainActor.run { self.state = .idle }
                    return
                }
                guard !data.isEmpty else {
                    print("AudioEngine: Empty audio data from URL")
                    await MainActor.run { self.state = .idle }
                    return
                }

                // Reconfigure to ensure speaker route right before playback
                try AudioSessionManager.shared.configureForConversation()

                // Play on main thread (AVAudioPlayer + Timer need it)
                await MainActor.run {
                    do {
                        try self.player.play(data: data)
                        print("AudioEngine: TTS playback started successfully")
                    } catch {
                        print("AudioEngine: Failed to play downloaded audio: \(error)")
                        self.state = .idle
                    }
                }
            } catch {
                print("AudioEngine: Failed to download TTS audio: \(error)")
                await MainActor.run { self.state = .idle }
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
