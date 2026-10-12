import Foundation

/// Splits text into pieces OpenAI accepts in one request.
/// The first piece is short, so speech starts quickly. Later pieces download while earlier ones play.
enum TextChunker {
    static func split(_ text: String, firstLimit: Int = 300, limit: Int = 1500) -> [String] {
        var sentences: [String] = []
        text.enumerateSubstrings(in: text.startIndex..., options: .bySentences) { sentence, _, _, _ in
            if let sentence { sentences.append(sentence) }
        }
        if sentences.isEmpty { sentences = [text] }

        var chunks: [String] = []
        var current = ""
        for sentence in sentences.flatMap({ splitLong($0, limit: limit) }) {
            let currentLimit = chunks.isEmpty ? firstLimit : limit
            if !current.isEmpty && current.count + sentence.count > currentLimit {
                chunks.append(current)
                current = ""
            }
            current += sentence
        }
        if !current.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { chunks.append(current) }
        return chunks
    }

    /// Breaks a sentence longer than `limit` at word boundaries.
    private static func splitLong(_ sentence: String, limit: Int) -> [String] {
        guard sentence.count > limit else { return [sentence] }
        var parts: [String] = []
        var current = ""
        for word in sentence.split(separator: " ", omittingEmptySubsequences: false) {
            if current.count + word.count + 1 > limit && !current.isEmpty {
                parts.append(current)
                current = ""
            }
            current += (current.isEmpty ? "" : " ") + word
        }
        if !current.isEmpty { parts.append(current) }
        return parts
    }
}
