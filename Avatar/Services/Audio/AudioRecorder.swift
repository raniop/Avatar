import AVFoundation
import Observation

@Observable
final class AudioRecorder {
    var isRecording = false
    var currentAmplitude: Float = 0

    var onAudioChunk: ((Data) -> Void)?

    private var audioEngine: AVAudioEngine?
    private var inputNode: AVAudioInputNode?
    private let bufferSize: AVAudioFrameCount = 4096

    func startRecording() throws {
        let engine = AVAudioEngine()
        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)

        // Convert to 16kHz mono for Whisper
        guard let targetFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: 16000,
            channels: 1,
            interleaved: false
        ) else { return }

        guard let converter = AVAudioConverter(from: format, to: targetFormat) else { return }

        input.installTap(onBus: 0, bufferSize: bufferSize, format: format) { [weak self] buffer, _ in
            guard let self else { return }

            // Calculate amplitude for visual feedback
            let channelData = buffer.floatChannelData?[0]
            let frameLength = Int(buffer.frameLength)
            var sum: Float = 0
            for i in 0..<frameLength {
                let sample = channelData?[i] ?? 0
                sum += sample * sample
            }
            let rms = sqrt(sum / Float(frameLength))
            self.currentAmplitude = rms

            // Convert to 16kHz mono
            let targetFrameCapacity = AVAudioFrameCount(
                Double(buffer.frameLength) * targetFormat.sampleRate / format.sampleRate
            )
            guard let convertedBuffer = AVAudioPCMBuffer(
                pcmFormat: targetFormat,
                frameCapacity: targetFrameCapacity
            ) else { return }

            var error: NSError?
            let status = converter.convert(to: convertedBuffer, error: &error) { _, outStatus in
                outStatus.pointee = .haveData
                return buffer
            }

            guard status != .error, error == nil else { return }

            // Convert to Data and send chunk
            if let channelData = convertedBuffer.floatChannelData?[0] {
                let data = Data(
                    bytes: channelData,
                    count: Int(convertedBuffer.frameLength) * MemoryLayout<Float>.size
                )
                self.onAudioChunk?(data)
            }
        }

        engine.prepare()
        try engine.start()

        self.audioEngine = engine
        self.inputNode = input
        isRecording = true
    }

    func stopRecording() {
        inputNode?.removeTap(onBus: 0)
        audioEngine?.stop()
        audioEngine = nil
        inputNode = nil
        isRecording = false
        currentAmplitude = 0
    }
}
