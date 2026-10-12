import Foundation

/// Plays a `Reading` from any sentence, and keeps playing as more audio arrives.
@MainActor
final class ReadingPlayer {
    private let audio = AudioPlayer()
    private let reading: Reading
    /// The next audio to schedule: a sentence, and how many of its bytes are already scheduled.
    private var cursor = (sentence: 0, byte: 0)
    /// The sentence of each scheduled piece of audio, in playing order.
    private var queued: [Int] = []
    private(set) var isPaused = false

    var rate: Float {
        get { audio.rate }
        set { audio.rate = newValue }
    }

    /// True when everything has arrived and been heard.
    var isFinished: Bool {
        queued.isEmpty && cursor.sentence >= reading.count && reading.allAudioArrived
    }

    init(reading: Reading) {
        self.reading = reading
    }

    func start(at sentence: Int = 0) throws {
        try audio.start()
        isPaused = false
        seek(to: sentence)
    }

    func seek(to sentence: Int) {
        audio.clear()
        queued = []
        cursor = (sentence, 0)
        reading.current = sentence
        if !isPaused { audio.play() }
        feed()
    }

    func setPaused(_ paused: Bool) {
        isPaused = paused
        if paused { audio.pause() } else { audio.play() }
    }

    func stop() {
        audio.shutDown()
        queued = []
        isPaused = false
    }

    /// Schedules all audio that has arrived after the cursor. Call it whenever new audio arrives.
    func feed() {
        while cursor.sentence < reading.count {
            let index = cursor.sentence
            let data = reading.audio[index]
            let end = data.count & ~1
            if end > cursor.byte {
                queued.append(index)
                if queued.count == 1 { reading.current = index }
                audio.schedule(data.subdata(in: cursor.byte..<end)) { [weak self] in self?.played() }
                cursor.byte = end
            }
            guard reading.isComplete(index) else { return }
            cursor = (index + 1, 0)
        }
    }

    private func played() {
        guard !queued.isEmpty else { return }
        queued.removeFirst()
        if let next = queued.first { reading.current = next }
    }
}
