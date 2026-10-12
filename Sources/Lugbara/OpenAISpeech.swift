import Foundation

/// Client for OpenAI's `POST /v1/audio/speech`.
/// Asks for raw PCM: 24 kHz, 16-bit signed little-endian, mono, no header.
struct OpenAISpeech {
    static let maxInputLength = 4096
    static let voices = ["marin", "cedar", "alloy", "ash", "ballad", "coral", "echo",
                         "fable", "nova", "onyx", "sage", "shimmer", "verse"]

    static let model = "gpt-4o-mini-tts-2025-12-15"

    let apiKey: String

    /// Streams the audio for `text` and calls `onAudio` with each piece of PCM as it arrives.
    func stream(text: String, voice: String, instructions: String,
                onAudio: @escaping (Data) -> Void) async throws {
        var request = URLRequest(url: URL(string: "https://api.openai.com/v1/audio/speech")!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "model": Self.model,
            "input": text,
            "voice": voice,
            "instructions": instructions,
            "response_format": "pcm",
        ])

        let (bytes, response) = try await URLSession.shared.bytes(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard status == 200 else {
            var body = Data()
            for try await byte in bytes { body.append(byte) }
            throw SpeechError.http(status: status, message: Self.errorMessage(from: body))
        }

        // About 100 ms of audio per piece.
        let pieceSize = 4800
        var piece = Data(capacity: pieceSize)
        for try await byte in bytes {
            piece.append(byte)
            if piece.count >= pieceSize {
                onAudio(piece)
                piece.removeAll(keepingCapacity: true)
            }
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

    var errorDescription: String? {
        switch self {
        case .http(401, _):
            return "OpenAI did not accept the API key. Change it below."
        case .http(429, let message):
            return "OpenAI rate limit or quota: \(message)"
        case .http(let status, let message):
            return "OpenAI error \(status): \(message)"
        }
    }
}
