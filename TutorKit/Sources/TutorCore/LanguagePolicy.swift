import NaturalLanguage

public enum LanguagePolicy {
    public static func replyLanguage(for transcript: String, setting: TutorLanguage) -> TutorLanguage {
        let wordCount = transcript.split(whereSeparator: { $0.isWhitespace }).count
        guard wordCount >= 3, !containsMixedLanguageMarkers(in: transcript) else { return setting }

        let recognizer = NLLanguageRecognizer()
        recognizer.languageConstraints = [.english, .spanish]
        recognizer.processString(transcript)

        guard let (language, probability) = recognizer.languageHypotheses(withMaximum: 1).first,
              probability >= 0.80
        else {
            return setting
        }

        switch language {
        case .english: return .english
        case .spanish: return .spanish
        default: return setting
        }
    }

    private static func containsMixedLanguageMarkers(in transcript: String) -> Bool {
        let words = Set(
            transcript.lowercased().split { !$0.isLetter }.map(String.init)
        )
        let englishMarkers: Set<String> = ["what", "is", "it", "the", "or", "not", "please", "times"]
        let spanishMarkers: Set<String> = [
            "cuánto", "es", "por", "tres", "cuartos", "siete", "ocho", "maestro", "sí",
        ]
        return !words.isDisjoint(with: englishMarkers) && !words.isDisjoint(with: spanishMarkers)
    }
}
