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

        // Convert to 16kHz mono 16-bit PCM for Whisper
        guard let targetFormat = AVAudioFormat(
            commonFormat: .pcmFormatInt16,
            sampleRate: 16000,
            channels: 1,
            interleaved: true
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

            // Convert to 16kHz mono 16-bit
            let ratio = targetFormat.sampleRate / format.sampleRate
            let targetFrameCapacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio) + 1
            guard targetFrameCapacity > 0,
                  let convertedBuffer = AVAudioPCMBuffer(
                    pcmFormat: targetFormat,
                    frameCapacity: targetFrameCapacity
                  ) else { return }

            // Reset converter state before each chunk to avoid stale internal buffers
            converter.reset()

            var error: NSError?
            var hasProvidedInput = false
            let status = converter.convert(to: convertedBuffer, error: &error) { _, outStatus in
                if hasProvidedInput {
                    outStatus.pointee = .noDataNow
                    return nil
                }
                hasProvidedInput = true
                outStatus.pointee = .haveData
                return buffer
            }

            guard status != .error, error == nil else { return }

            // Convert int16 samples to Data
            if convertedBuffer.frameLength > 0, let int16Data = convertedBuffer.int16ChannelData?[0] {
                let data = Data(
                    bytes: int16Data,
                    count: Int(convertedBuffer.frameLength) * MemoryLayout<Int16>.size
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

    /// Build a proper WAV file from raw 16-bit PCM data.
    /// Whisper API requires a recognizable audio format -- raw PCM is not enough.
    static func buildWAVData(from pcmData: Data, sampleRate: Int = 16000, channels: Int = 1, bitsPerSample: Int = 16) -> Data {
        var wav = Data()

        let byteRate = sampleRate * channels * (bitsPerSample / 8)
        let blockAlign = channels * (bitsPerSample / 8)
        let dataSize = pcmData.count
        let fileSize = 36 + dataSize

        // RIFF header
        wav.append(contentsOf: "RIFF".utf8)
        wav.append(contentsOf: withUnsafeBytes(of: UInt32(fileSize).littleEndian) { Array($0) })
        wav.append(contentsOf: "WAVE".utf8)

        // fmt sub-chunk
        wav.append(contentsOf: "fmt ".utf8)
        wav.append(contentsOf: withUnsafeBytes(of: UInt32(16).littleEndian) { Array($0) })
        wav.append(contentsOf: withUnsafeBytes(of: UInt16(1).littleEndian) { Array($0) })
        wav.append(contentsOf: withUnsafeBytes(of: UInt16(channels).littleEndian) { Array($0) })
        wav.append(contentsOf: withUnsafeBytes(of: UInt32(sampleRate).littleEndian) { Array($0) })
        wav.append(contentsOf: withUnsafeBytes(of: UInt32(byteRate).littleEndian) { Array($0) })
        wav.append(contentsOf: withUnsafeBytes(of: UInt16(blockAlign).littleEndian) { Array($0) })
        wav.append(contentsOf: withUnsafeBytes(of: UInt16(bitsPerSample).littleEndian) { Array($0) })

        // data sub-chunk
        wav.append(contentsOf: "data".utf8)
        wav.append(contentsOf: withUnsafeBytes(of: UInt32(dataSize).littleEndian) { Array($0) })
        wav.append(pcmData)

        return wav
    }
}
