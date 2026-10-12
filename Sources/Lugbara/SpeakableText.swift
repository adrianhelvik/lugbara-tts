import Foundation

/// Makes text from a terminal or a chat easier to listen to, without AI.
/// Code is replaced by a short spoken marker, because the listener looks at the screen for code anyway.
enum SpeakableText {
    static func prepare(_ text: String, codeMarker: String) -> String {
        var output: [String] = []
        var inFence = false
        var inCode = false

        func startCode() {
            if !inCode { output.append(codeMarker) }
            inCode = true
        }

        let lines = text.components(separatedBy: .newlines)
        for (index, line) in lines.enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("```") {
                inFence.toggle()
                startCode()
                continue
            }
            if inFence { continue }
            if trimmed.isEmpty {
                // A blank line between two pieces of code keeps them one block.
                let next = lines[(index + 1)...].first { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
                if inCode, let next, looksLikeCode(next) { continue }
                inCode = false
                output.append("")
                continue
            }
            if looksLikeCode(line) {
                startCode()
                continue
            }
            inCode = false
            var spoken = cleanProse(trimmed)
            // A heading or list item has no full stop. Without one, the voice runs on into the next line.
            let next = index + 1 < lines.count ? lines[index + 1] : nil
            if let last = spoken.last, !".!?:;,".contains(last), next.map(startsNewBlock) ?? true {
                spoken += "."
            }
            output.append(spoken)
        }
        return output.joined(separator: "\n")
    }

    /// True for a blank line, a list item, or code. The line before it then ends a sentence.
    private static func startsNewBlock(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty || looksLikeCode(line)
            || trimmed.range(of: #"^([⏺•*·>#]|-\s|—|\d+[.)]\s)"#, options: .regularExpression) != nil
    }

    /// A line counts as code when it ends like code, or has two or more signs of code.
    static func looksLikeCode(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return false }
        if ["{", "}", "};", "});", ")", "]"].contains(trimmed) { return true }
        if trimmed.hasSuffix("{") || trimmed.hasSuffix(";") { return true }
        if trimmed.hasPrefix("//") || trimmed.hasPrefix("/*") { return true }

        // A diff line: "+" or "-" right before the code, as in "-export function".
        // With spaces after the sign, as in "+  // a comment", the rest must look like code by itself.
        if let first = trimmed.first, first == "+" || first == "-",
           let second = trimmed.dropFirst().first, second != first {
            if !second.isWhitespace { return true }
            if looksLikeCode(String(trimmed.dropFirst())) { return true }
        }

        let signs = ["=>", "===", "!==", "&&", "||", "??", "::", " = ", "//", "if (", "return ",
                     "const ", "let ", "var ", "func ", "def ", "export ", "import ", "?.", "();", "){"]
        return signs.filter { trimmed.contains($0) }.count >= 2
    }

    private static func cleanProse(_ line: String) -> String {
        var text = line
        // Bullets and decorations at the start of a line.
        text = text.replacingOccurrences(of: #"^([⏺•*·>]|#+|-(?=\s)|—)\s*"#, with: "", options: .regularExpression)
        if text.allSatisfy({ "-─—=_*".contains($0) }) { return "" }
        // A file path is read as its file name without the extension.
        text = text.replacingOccurrences(of: #"(?:[\w.@-]+/)+([\w-]+)(?:\.\w+)?"#, with: "$1", options: .regularExpression)
        // camelCase and snake_case become separate words.
        text = text.replacingOccurrences(of: #"([a-z0-9])([A-Z])"#, with: "$1 $2", options: .regularExpression)
        text = text.replacingOccurrences(of: #"(\w)_(\w)"#, with: "$1 $2", options: .regularExpression)
        // Markdown marks.
        text = text.replacingOccurrences(of: #"\*\*|`|__"#, with: "", options: .regularExpression)
        text = text.replacingOccurrences(of: "→", with: ", ")
        return text
    }
}
