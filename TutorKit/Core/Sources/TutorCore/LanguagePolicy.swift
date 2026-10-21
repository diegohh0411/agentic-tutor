import NaturalLanguage

public enum LanguagePolicy {
    public static func replyLanguage(for transcript: String, setting: TutorLanguage) -> TutorLanguage {
        let wordCount = transcript.split(whereSeparator: { $0.isWhitespace }).count
        guard wordCount >= 3, !isMixedLanguageTurn(transcript) else { return setting }

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

    private static func isMixedLanguageTurn(_ transcript: String) -> Bool {
        var languageCounts: [NLLanguage: Int] = [.english: 0, .spanish: 0]

        for token in transcript.split(whereSeparator: { !$0.isLetter && !isSpanishCharacter($0) })
        where token.filter(\.isLetter).count >= 3 {
            if token.contains(where: isSpanishCharacter) {
                languageCounts[.spanish, default: 0] += 1
                continue
            }

            let recognizer = NLLanguageRecognizer()
            recognizer.languageConstraints = [.english, .spanish]
            recognizer.processString(String(token))

            guard let (language, probability) = recognizer.languageHypotheses(withMaximum: 1).first,
                  probability >= 0.75,
                  language == .english || language == .spanish
            else {
                continue
            }

            languageCounts[language, default: 0] += 1
        }

        let englishCount = languageCounts[.english, default: 0]
        let spanishCount = languageCounts[.spanish, default: 0]
        let countedTokenCount = englishCount + spanishCount
        guard englishCount >= 1, spanishCount >= 1, countedTokenCount > 0 else { return false }

        return Double(englishCount) / Double(countedTokenCount) >= 0.20
            && Double(spanishCount) / Double(countedTokenCount) >= 0.20
    }

    private static func isSpanishCharacter(_ character: Character) -> Bool {
        "ñáéíóúü¿¡".contains(character)
    }
}
