import Foundation

public enum SpokenMath {
    public static func speakable(_ text: String, language: TutorLanguage) -> String {
        var result = replaceMatches("(\\d+)\\/(\\d+)", in: text) { match in
            let numerator = match[1]
            let denominator = Int(match[2])!
            guard (2...10).contains(denominator) else {
                return language == .english
                    ? "\(numerator) over \(match[2])"
                    : "\(numerator) sobre \(match[2])"
            }

            let spokenNumerator = namedFractionNumerator(numerator, language: language)
            let denominatorName = namedDenominator(
                denominator,
                singular: numerator == "1",
                language: language
            )
            return "\(spokenNumerator) \(denominatorName)"
        }

        result = replaceMatches("([[:alnum:]]+)²", in: result) { match in
            "\(match[1]) \(language == .english ? "squared" : "al cuadrado")"
        }
        result = replaceMatches("([[:alnum:]]+)³", in: result) { match in
            "\(match[1]) \(language == .english ? "cubed" : "al cubo")"
        }
        result = replaceMatches("([[:alnum:]]+)\\^([0-9]+)", in: result) { match in
            let exponent = match[2]
            let suffix: String
            switch (language, exponent) {
            case (.english, "2"): suffix = "squared"
            case (.english, "3"): suffix = "cubed"
            case (.english, _): suffix = "to the power of \(exponent)"
            case (.spanish, "2"): suffix = "al cuadrado"
            case (.spanish, "3"): suffix = "al cubo"
            case (.spanish, _): suffix = "a la \(exponent)"
            }
            return "\(match[1]) \(suffix)"
        }

        result = replaceMatches("(\\d+)\\.(\\d+)", in: result) { match in
            "\(match[1]) \(language == .english ? "point" : "punto") \(match[2])"
        }

        result = replaceMatches("√\\s*([[:alnum:].]+)", in: result) { match in
            language == .english
                ? "the square root of \(match[1])"
                : "la raíz cuadrada de \(match[1])"
        }
        result = replaceMatches("(?<=[[:alnum:]])\\s*[-−]\\s*(?=[[:alnum:]])", in: result) { _ in
            language == .english ? " minus " : " menos "
        }

        let operators: [(String, String, String)] = [
            ("×|\\*", "times", "por"),
            ("÷", "divided by", "entre"),
            ("=", "equals", "es igual a"),
            ("\\+", "plus", "más"),
            ("%", "percent", "por ciento"),
        ]
        for (pattern, english, spanish) in operators {
            result = replaceMatches(pattern, in: result) { _ in
                " \(language == .english ? english : spanish) "
            }
        }
        return result.split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
    }

    private static func namedFractionNumerator(_ numerator: String, language: TutorLanguage) -> String {
        guard let value = Int(numerator), (1...10).contains(value) else { return numerator }
        let english = ["one", "two", "three", "four", "five", "six", "seven", "eight", "nine", "ten"]
        let spanish = ["un", "dos", "tres", "cuatro", "cinco", "seis", "siete", "ocho", "nueve", "diez"]
        return (language == .english ? english : spanish)[value - 1]
    }

    private static func namedDenominator(_ value: Int, singular: Bool, language: TutorLanguage) -> String {
        let englishSingular = ["half", "third", "quarter", "fifth", "sixth", "seventh", "eighth", "ninth", "tenth"]
        let spanishSingular = ["medio", "tercio", "cuarto", "quinto", "sexto", "séptimo", "octavo", "noveno", "décimo"]
        let name = (language == .english ? englishSingular : spanishSingular)[value - 2]
        guard !singular else { return name }
        if language == .english, value == 2 { return "halves" }
        return name + "s"
    }

    private static func replaceMatches(
        _ pattern: String,
        in text: String,
        transform: ([String]) -> String
    ) -> String {
        let regex = try! NSRegularExpression(pattern: pattern)
        let range = NSRange(text.startIndex..., in: text)
        let matches = regex.matches(in: text, range: range)
        return matches.reversed().reduce(text) { result, match in
            let captures = (0..<match.numberOfRanges).map { index in
                guard let range = Range(match.range(at: index), in: result) else { return "" }
                return String(result[range])
            }
            guard let range = Range(match.range, in: result) else { return result }
            return result.replacingCharacters(in: range, with: transform(captures))
        }
    }
}
