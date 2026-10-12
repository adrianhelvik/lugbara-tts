import NaturalLanguage

enum SpokenLanguage: String, CaseIterable {
    case auto, norwegian, english

    var title: String {
        switch self {
        case .auto: "Auto"
        case .norwegian: "Norsk"
        case .english: "English"
        }
    }

    var instructions: String {
        switch self {
        case .norwegian, .auto:
            "Speak Norwegian Bokmål with a natural Eastern Norwegian (Oslo) accent. Calm, clear, neutral reading voice."
        case .english:
            "Speak natural, clear English. Calm, neutral reading voice."
        }
    }

    /// Picks Norwegian or English for `text`.
    static func detect(_ text: String) -> SpokenLanguage {
        let recognizer = NLLanguageRecognizer()
        recognizer.languageConstraints = [.norwegian, .english]
        recognizer.processString(text)
        return recognizer.dominantLanguage == .norwegian ? .norwegian : .english
    }
}
