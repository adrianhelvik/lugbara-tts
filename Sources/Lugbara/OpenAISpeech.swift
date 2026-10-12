import Foundation
import os

/// Client for OpenAI's `POST /v1/audio/speech`.
/// Asks for raw PCM: 24 kHz, 16-bit signed little-endian, mono, no header.
struct OpenAISpeech {
    static let maxInputLength = 4096
    static let voices = ["marin", "cedar", "alloy", "ash", "ballad", "coral", "echo",
                         "fable", "nova", "onyx", "sage", "shimmer", "verse"]

    static let model = "gpt-4o-mini-tts-2025-12-15"

    let apiKey: String
    var session: URLSession = .shared
    /// A normal answer starts within a second. OpenAI sometimes sends nothing at all, so after
    /// this long without audio the request is sent again.
    var firstAudioTimeout: Duration = .seconds(4)
    var attempts = 3

    /// Streams the audio for `text` and calls `onAudio` with each piece of PCM as it arrives.
    /// Sends the request again when no audio arrives in time.
    func stream(text: String, voice: String, instructions: String,
                onAudio: @escaping @Sendable (Data) -> Void) async throws {
        for attempt in 1...attempts {
            do {
                try await streamOnce(text: text, voice: voice, instructions: instructions, onAudio: onAudio)
                return
            } catch SpeechError.noAudio where attempt < attempts {
                log.info("No audio after \(firstAudioTimeout) on attempt \(attempt). Sending the request again")
            }
        }
    }

    private func streamOnce(text: String, voice: String, instructions: String,
                            onAudio: @escaping @Sendable (Data) -> Void) async throws {
        let receivedAudio = OSAllocatedUnfairLock(initialState: false)
        // Two tasks race: the download, and a timer that fails the request if no audio came in time.
        // Each returns true when it is the download that finished.
        try await withThrowingTaskGroup(of: Bool.self) { group in
            group.addTask {
                try await download(text: text, voice: voice, instructions: instructions) { pcm in
                    receivedAudio.withLock { $0 = true }
                    onAudio(pcm)
                }
                return true
            }
            group.addTask {
                try? await Task.sleep(for: firstAudioTimeout)
                if !Task.isCancelled && !receivedAudio.withLock({ $0 }) { throw SpeechError.noAudio }
                return false
            }
            for try await downloadFinished in group where downloadFinished {
                group.cancelAll()
            }
        }
    }

    private func download(text: String, voice: String, instructions: String,
                          onAudio: @escaping (Data) -> Void) async throws {
        var request = URLRequest(url: URL(string: "https://api.openai.com/v1/audio/speech")!)
        request.httpMethod = "POST"
        // Audio streams continuously, so 10 s without data means the answer has stalled.
        request.timeoutInterval = 10
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "model": Self.model,
            "input": text,
            "voice": voice,
            "instructions": instructions,
            "response_format": "pcm",
        ])

        let (bytes, response) = try await session.bytes(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard status == 200 else {
            var body = Data()
            for try await byte in bytes { body.append(byte) }
            throw SpeechError.http(status: status, message: Self.errorMessage(from: body))
        }

        // About 100 ms of audio per piece.
        let pieceSize = 4800
        var piece = Data(capacity: pieceSize)
        var sentAny = false
        do {
            for try await byte in bytes {
                piece.append(byte)
                if piece.count >= pieceSize {
                    onAudio(piece)
                    sentAny = true
                    piece.removeAll(keepingCapacity: true)
                }
            }
        } catch let error as URLError where error.code == .timedOut && (sentAny || !piece.isEmpty) {
            // Stalled halfway. Keep what arrived rather than play the start of the sentence twice.
            log.info("Audio stalled halfway through a sentence. Keeping what arrived")
        }
        if !piece.isEmpty { onAudio(piece) }
    }

    private static func errorMessage(from body: Data) -> String {
        if let json = try? JSONSerialization.jsonObject(with: body) as? [String: Any],
           let error = json["error"] as? [String: Any],
           let message = error["message"] as? String {
            return message
        }
        return String(data: body, encoding: .utf8) ?? ""
    }
}

enum SpeechError: LocalizedError {
    case http(status: Int, message: String)
    case noAudio

    var errorDescription: String? {
        switch self {
        case .http(401, _):
            return "OpenAI did not accept the API key. Change it below."
        case .http(429, let message):
            return "OpenAI rate limit or quota: \(message)"
        case .http(let status, let message):
            return "OpenAI error \(status): \(message)"
        case .noAudio:
            return "OpenAI sent no audio after several tries."
        }
    }
}
