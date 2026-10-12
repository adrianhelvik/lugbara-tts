import AppKit

/// Reads the selected text aloud, and lets the listener pause, go back and replay.
@MainActor
final class Speaker: ObservableObject {
    static let shared = Speaker()

    /// True while a reading is downloading or playing.
    @Published private(set) var isSpeaking = false
    @Published private(set) var isPaused = false
    @Published var lastError: String?
    @Published var hasAPIKey = false

    let reading = Reading()
    private lazy var player = ReadingPlayer(reading: reading)
    private var task: Task<Void, Never>?
    // Audio that arrives for an earlier request carries an old number and is dropped.
    private var requestNumber = 0

    var speed: Float = 1.0 {
        didSet { player.rate = speed }
    }

    func toggle() {
        if isSpeaking { stop() } else { speakSelection() }
    }

    func stop() {
        requestNumber += 1
        task?.cancel()
        task = nil
        player.stop()
        reading.keepWhatArrived()
        isSpeaking = false
        isPaused = false
    }

    func togglePause() {
        guard isSpeaking else {
            if !reading.isEmpty { replay(from: reading.current ?? 0) }
            return
        }
        isPaused.toggle()
        player.setPaused(isPaused)
    }

    /// Goes back one sentence. The listener presses this after drifting off.
    func back() {
        guard !reading.isEmpty else { return }
        jump(to: max((reading.current ?? reading.count) - 1, 0))
    }

    func forward() {
        guard let current = reading.current, current + 1 < reading.count,
              reading.sentences[current + 1].canPlay else { return }
        jump(to: current + 1)
    }

    func jump(to sentence: Int) {
        guard reading.sentences.indices.contains(sentence), reading.sentences[sentence].canPlay else { return }
        if isSpeaking { player.seek(to: sentence) } else { replay(from: sentence) }
    }

    /// Plays audio that has already arrived again, without a new request.
    private func replay(from sentence: Int) {
        requestNumber += 1
        isSpeaking = true
        isPaused = false
        lastError = nil
        task = Task {
            do {
                player.rate = speed
                try player.start(at: sentence)
                try await waitUntilHeard()
            } catch is CancellationError {
            } catch {
                lastError = error.localizedDescription
            }
            if !Task.isCancelled { finish() }
        }
    }

    private func speakSelection() {
        guard let apiKey = Keychain.readAPIKey() else {
            lastError = "No OpenAI API key yet. Add one below."
            NSSound.beep()
            return
        }
        requestNumber += 1
        isSpeaking = true
        isPaused = false
        lastError = nil
        task = Task {
            guard let text = await Selection.read() else {
                lastError = Selection.hasAccessibilityPermission
                    ? "No selected text found."
                    : "Lugbara needs Accessibility permission to read the selection."
                NSSound.beep()
                if !Task.isCancelled { isSpeaking = false }
                return
            }
            log.info("Selection: \(text.count) characters")
            await speak(text, apiKey: apiKey)
            if !Task.isCancelled { finish() }
        }
    }

    private func speak(_ text: String, apiKey: String) async {
        let defaults = UserDefaults.standard
        let voice = defaults.string(forKey: Settings.voice) ?? Settings.defaultVoice
        let chosen = SpokenLanguage(rawValue: defaults.string(forKey: Settings.language) ?? "") ?? .auto
        let useAI = defaults.object(forKey: Settings.smartReading) as? Bool ?? true
        let api = OpenAISpeech(apiKey: apiKey)
        let request = requestNumber

        do {
            reading.reset()
            player.rate = speed
            try player.start()
            let pieces = ReadingPieces.make(from: text, apiKey: apiKey, useAI: useAI, chosen: chosen)
            for try await piece in pieces {
                try Task.checkCancellation()
                let index = reading.add(piece.text, language: piece.language)
                log.info("Speech request \(index): \(piece.text.count) characters")
                try await api.stream(text: piece.text, voice: voice, instructions: piece.language.instructions) { pcm in
                    Task { @MainActor in
                        guard self.requestNumber == request else { return }
                        self.reading.addAudio(pcm, to: index)
                        self.player.feed()
                    }
                }
                // Queued behind the audio above, so the sentence is marked complete after its last audio.
                Task { @MainActor in
                    guard self.requestNumber == request else { return }
                    self.reading.markComplete(index)
                    self.player.feed()
                }
            }
            log.info("All \(self.reading.count) speech requests sent")
            try await waitUntilHeard()
        } catch is CancellationError {
            log.info("Reading cancelled")
        } catch let error as URLError where error.code == .cancelled {
            log.info("Reading cancelled")
        } catch {
            log.error("Reading failed: \(error.localizedDescription, privacy: .public)")
            lastError = error.localizedDescription
            NSSound.beep()
        }
    }

    /// Downloads finish before playback does. Waits for the last audio to be heard, including after jumps.
    private func waitUntilHeard() async throws {
        while !player.isFinished {
            try await Task.sleep(for: .milliseconds(100))
        }
    }

    private func finish() {
        player.stop()
        reading.keepWhatArrived()
        isSpeaking = false
        isPaused = false
    }
}
