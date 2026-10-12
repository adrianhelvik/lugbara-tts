import Foundation

/// Splits text into sentences, so each one can be sent to the voice alone and replayed alone.
enum TextChunker {
    /// Sentences longer than `maxLength` are broken at word boundaries. OpenAI accepts up to 4096 characters.
    static func sentences(_ text: String, maxLength: Int = 600) -> [String] {
        var sentences: [String] = []
        text.enumerateSubstrings(in: text.startIndex..., options: .bySentences) { sentence, _, _, _ in
            guard let sentence else { return }
            let trimmed = sentence.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty { sentences.append(contentsOf: splitLong(trimmed, limit: maxLength)) }
        }
        return sentences
    }

    private static func splitLong(_ sentence: String, limit: Int) -> [String] {
        guard sentence.count > limit else { return [sentence] }
        var parts: [String] = []
        var current = ""
        for word in sentence.split(separator: " ") {
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
