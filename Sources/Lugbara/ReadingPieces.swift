import Foundation

/// A piece of text to send to the voice in one request, with the language to read it in.
struct ReadingPiece {
    var text: String
    var language: SpokenLanguage
}

/// Turns the selected text into pieces for the voice, in reading order.
/// With AI on, the first paragraph is read at once with the fixed rules, while GPT-6 Luna rewrites the rest.
/// Without AI, or when Luna is slow or fails, the fixed rules handle everything.
@MainActor
enum ReadingPieces {
    /// How long to wait for Luna's first line before reading the rest with the fixed rules instead.
    static let lunaDeadline: Duration = .seconds(5)

    static func make(from text: String, apiKey: String, useAI: Bool,
                     chosen: SpokenLanguage) -> AsyncThrowingStream<ReadingPiece, Error> {
        let wholeText = chosen == .auto ? SpokenLanguage.detect(text) : chosen
        return AsyncThrowingStream { continuation in
            let task = Task { @MainActor in
                var rest = text
                if useAI {
                    let (head, tail) = splitFirstParagraph(text)
                    let luna = Task { @MainActor () throws -> Bool in
                        guard !tail.isEmpty else { return true }
                        return try await fromLuna(tail, apiKey: apiKey, chosen: chosen, fallback: wholeText,
                                                  headIsPlaying: !head.isEmpty, yield: { continuation.yield($0) })
                    }
                    // Luna starts on the rest, and yields only after the head below is queued.
                    for piece in fromRules(head, language: wholeText) { continuation.yield(piece) }
                    do {
                        if try await luna.value {
                            continuation.finish()
                            return
                        }
                    } catch {
                        continuation.finish(throwing: error)
                        return
                    }
                    rest = tail
                }
                for piece in fromRules(rest, language: wholeText) { continuation.yield(piece) }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    /// Splits off the first paragraph, at most about 400 characters, so it can be read before Luna answers.
    /// Returns an empty head when the paragraph contains code, since Luna reads code better.
    static func splitFirstParagraph(_ text: String) -> (head: String, tail: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let paragraphEnd = trimmed.range(of: #"\n[ \t]*\n"#, options: .regularExpression)?.lowerBound ?? trimmed.endIndex
        let paragraph = trimmed[..<paragraphEnd]
        if paragraph.components(separatedBy: .newlines).contains(where: SpeakableText.looksLikeCode) {
            return ("", trimmed)
        }
        var headEnd = paragraph.startIndex
        paragraph.enumerateSubstrings(in: paragraph.startIndex..., options: .bySentences) { _, range, _, stop in
            if headEnd > paragraph.startIndex && paragraph.distance(from: paragraph.startIndex, to: range.upperBound) > 400 {
                stop = true
                return
            }
            headEnd = range.upperBound
        }
        if headEnd == paragraph.startIndex { headEnd = paragraphEnd }
        return (String(trimmed[..<headEnd]), String(trimmed[headEnd...]).trimmingCharacters(in: .whitespacesAndNewlines))
    }

    /// Fixed rules: code becomes "Kodeblokk." or "Code block.", and the rest is cleaned up.
    static func fromRules(_ text: String, language: SpokenLanguage) -> [ReadingPiece] {
        let marker = language == .norwegian ? "Kodeblokk." : "Code block."
        return TextChunker.split(SpeakableText.prepare(text, codeMarker: marker))
            .map { ReadingPiece(text: $0, language: language) }
    }

    /// Returns false when Luna gave no line before the deadline or failed before its first line.
    /// The caller then reads with the fixed rules. Throws when Luna fails after reading has started.
    private static func fromLuna(_ text: String, apiKey: String, chosen: SpokenLanguage, fallback: SpokenLanguage,
                                 headIsPlaying: Bool, yield: @escaping (ReadingPiece) -> Void) async throws -> Bool {
        var started = false
        var buffer: ReadingPiece?

        func send(_ line: SpokenLine) {
            let language = chosen == .auto ? (line.language ?? fallback) : chosen
            // With nothing playing yet, the first line goes out alone, so speech starts quickly.
            // Other lines are grouped into pieces of about 300 characters in one language.
            if !started {
                started = true
                if !headIsPlaying {
                    yield(ReadingPiece(text: line.text, language: language))
                    return
                }
            }
            if var current = buffer, current.language == language {
                current.text += " " + line.text
                buffer = current
            } else {
                if let current = buffer { yield(current) }
                buffer = ReadingPiece(text: line.text, language: language)
            }
            if let current = buffer, current.text.count >= 300 {
                yield(current)
                buffer = nil
            }
        }

        let luna = Task { @MainActor in
            try await LunaRewriter(apiKey: apiKey).rewrite(text, onLine: send)
        }
        let deadline = Task { @MainActor in
            try await Task.sleep(for: lunaDeadline)
            if !started { luna.cancel() }
        }
        defer { deadline.cancel() }

        do {
            try await withTaskCancellationHandler {
                try await luna.value
            } onCancel: {
                luna.cancel()
            }
        } catch {
            if Task.isCancelled { throw CancellationError() }
            if !started { return false }
            throw error
        }
        if let current = buffer { yield(current) }
        return started
    }
}
