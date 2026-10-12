import AppKit

/// Reads the selected text aloud. Calling `toggle()` while speaking stops it.
@MainActor
final class Speaker: ObservableObject {
    static let shared = Speaker()

    @Published private(set) var isSpeaking = false
    @Published var lastError: String?
    @Published var hasAPIKey = false

    private let player = AudioPlayer()
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
        isSpeaking = false
    }

    private func speakSelection() {
        guard let apiKey = Keychain.readAPIKey() else {
            lastError = "No OpenAI API key yet. Add one below."
            NSSound.beep()
            return
        }
        requestNumber += 1
        isSpeaking = true
        lastError = nil
        task = Task {
            defer { if !Task.isCancelled { self.isSpeaking = false } }
            guard let text = await Selection.read() else {
                lastError = Selection.hasAccessibilityPermission
                    ? "No selected text found."
                    : "Lugbara needs Accessibility permission to read the selection."
                NSSound.beep()
                return
            }
            await speak(text, apiKey: apiKey)
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
            player.rate = speed
            try player.start()
            let pieces = ReadingPieces.make(from: text, apiKey: apiKey, useAI: useAI, chosen: chosen)
            for try await piece in pieces {
                try Task.checkCancellation()
                try await api.stream(text: piece.text, voice: voice, instructions: piece.language.instructions) { pcm in
                    Task { @MainActor in
                        guard self.requestNumber == request else { return }
                        self.player.enqueue(pcm)
                    }
                }
            }
            // Downloads finish before playback does. Wait for the last buffer to play.
            while !Task.isCancelled && !player.isIdle {
                try await Task.sleep(for: .milliseconds(100))
            }
        } catch is CancellationError {
        } catch let error as URLError where error.code == .cancelled {
        } catch {
            lastError = error.localizedDescription
            NSSound.beep()
        }
        if !Task.isCancelled { player.stop() }
    }
}
