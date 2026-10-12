import AVFoundation

/// Plays the raw PCM from OpenAI as it arrives, at an adjustable speed.
@MainActor
final class AudioPlayer {
    private let engine = AVAudioEngine()
    private let node = AVAudioPlayerNode()
    private let timePitch = AVAudioUnitTimePitch()
    private let format = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 24_000,
                                       channels: 1, interleaved: false)!
    private var leftoverByte: UInt8?
    private var buffersPlaying = 0
    // Completion callbacks from before the last stop() carry an old generation and are ignored.
    private var generation = 0

    var rate: Float {
        get { timePitch.rate }
        set { timePitch.rate = newValue }
    }

    var isIdle: Bool { buffersPlaying == 0 }

    init() {
        engine.attach(node)
        engine.attach(timePitch)
        engine.connect(node, to: timePitch, format: format)
        engine.connect(timePitch, to: engine.mainMixerNode, format: format)
    }

    func start() throws {
        if !engine.isRunning { try engine.start() }
        node.play()
    }

    /// Takes 16-bit signed little-endian samples. A piece may end in the middle of a sample.
    func enqueue(_ data: Data) {
        var bytes = [UInt8]()
        bytes.reserveCapacity(data.count + 1)
        if let leftover = leftoverByte { bytes.append(leftover) }
        bytes.append(contentsOf: data)
        leftoverByte = bytes.count % 2 == 1 ? bytes.removeLast() : nil

        let frameCount = bytes.count / 2
        guard frameCount > 0,
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(frameCount))
        else { return }
        buffer.frameLength = AVAudioFrameCount(frameCount)
        let samples = buffer.floatChannelData![0]
        for i in 0..<frameCount {
            let value = Int16(bitPattern: UInt16(bytes[2 * i]) | UInt16(bytes[2 * i + 1]) << 8)
            samples[i] = Float(value) / 32_768
        }

        buffersPlaying += 1
        let scheduledIn = generation
        node.scheduleBuffer(buffer, completionCallbackType: .dataPlayedBack) { [weak self] _ in
            DispatchQueue.main.async {
                guard let self, self.generation == scheduledIn else { return }
                self.buffersPlaying -= 1
            }
        }
    }

    func stop() {
        generation += 1
        buffersPlaying = 0
        leftoverByte = nil
        node.stop()
        engine.stop()
    }
}
