import AVFoundation

/// Plays raw PCM from OpenAI (24 kHz, 16-bit signed little-endian, mono) at an adjustable speed.
@MainActor
final class AudioPlayer {
    private let engine = AVAudioEngine()
    private let node = AVAudioPlayerNode()
    private let timePitch = AVAudioUnitTimePitch()
    private let format = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 24_000,
                                       channels: 1, interleaved: false)!
    // Callbacks from audio scheduled before the last clear() carry an old generation and are ignored.
    private var generation = 0

    var rate: Float {
        get { timePitch.rate }
        set { timePitch.rate = newValue }
    }

    init() {
        engine.attach(node)
        engine.attach(timePitch)
        engine.connect(node, to: timePitch, format: format)
        engine.connect(timePitch, to: engine.mainMixerNode, format: format)
    }

    func start() throws {
        if !engine.isRunning { try engine.start() }
    }

    func play() { node.play() }
    func pause() { node.pause() }

    /// Plays `pcm` after everything scheduled before it, and calls `onPlayed` once it has been heard.
    /// `pcm` must hold whole samples, so an even number of bytes.
    func schedule(_ pcm: Data, onPlayed: @escaping () -> Void) {
        let frameCount = pcm.count / 2
        guard frameCount > 0,
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(frameCount))
        else { return }
        buffer.frameLength = AVAudioFrameCount(frameCount)
        let samples = buffer.floatChannelData![0]
        pcm.withUnsafeBytes { raw in
            for i in 0..<frameCount {
                samples[i] = Float(Int16(littleEndian: raw.loadUnaligned(fromByteOffset: 2 * i, as: Int16.self))) / 32_768
            }
        }

        let scheduledIn = generation
        node.scheduleBuffer(buffer, completionCallbackType: .dataPlayedBack) { [weak self] _ in
            DispatchQueue.main.async {
                guard let self, self.generation == scheduledIn else { return }
                onPlayed()
            }
        }
    }

    /// Drops everything scheduled. The player stays stopped until `play()`.
    func clear() {
        generation += 1
        node.stop()
    }

    func shutDown() {
        clear()
        engine.stop()
    }
}
