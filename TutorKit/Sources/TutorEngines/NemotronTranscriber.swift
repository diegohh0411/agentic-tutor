import Foundation
import NemotronStreamingASR
import TutorCore

/// Adapts Nemotron's stateful streaming recognizer to the tutor's ASR port.
///
/// The underlying model and its sessions are not thread-safe. The owning
/// `ConversationEngine` actor calls this adapter serially and maintains one
/// session for each user turn.
public final class NemotronTranscriber: StreamingTranscribing {
    public static let mathVocabulary: [TutorLanguage: [String]] = [
        .english: [
            "add", "subtract", "multiply", "divide", "times", "divided by",
            "plus", "minus", "equals", "fraction", "fractions", "numerator",
            "denominator", "hypotenuse", "triangle", "perimeter", "area", "decimal",
            "point", "integer", "negative", "positive", "square", "squared",
            "square root", "exponent", "variable", "equation", "solve", "meters",
            "centimeters", "quarters", "half", "fifths",
        ],
        .spanish: [
            "suma", "resta", "multiplica", "divide", "por", "entre", "más",
            "menos", "igual", "fracción", "fracciones", "numerador", "denominador",
            "hipotenusa", "triángulo", "perímetro", "área", "decimal", "punto",
            "entero", "negativo", "positivo", "cuadrado", "al cuadrado", "raíz cuadrada",
            "exponente", "variable", "ecuación", "resuelve", "metros", "centímetros",
            "cuartos", "medio", "quintos",
        ],
    ]

    private let model: NemotronStreamingASRModel
    private var session: StreamingSession?
    private var latestText = ""

    private init(model: NemotronStreamingASRModel) {
        self.model = model
    }

    /// Downloads (on first use), loads, and warms Nemotron's Core ML INT8 model.
    public static func load() async throws -> NemotronTranscriber {
        let model = try await NemotronStreamingASRModel.fromPretrained()
        try model.warmUp()
        return NemotronTranscriber(model: model)
    }

    /// Chooses Mexican Spanish when that prompt is present in the loaded model.
    public func asrLocale(for language: TutorLanguage) -> String {
        guard language == .spanish else { return language.asrLocale }
        return model.languages.promptDictionary["es-MX"] == nil ? language.asrLocale : "es-MX"
    }

    public func begin(language: TutorLanguage) throws {
        let phrases = Self.mathVocabulary[language] ?? []
        let suggestions = model.wordBoostingSuggestions(for: phrases)
        let boostedPhrases = zip(phrases, suggestions).map {
            WordBoostingConfig.Phrase($0.0, boost: $0.1.suggestedBoost)
        }
        session = try model.createSession(
            language: asrLocale(for: language),
            wordBoosting: WordBoostingConfig(phrases: boostedPhrases)
        )
        latestText = ""
    }

    public func push(_ chunk: [Float]) throws -> TranscriptUpdate? {
        guard let session else { throw NemotronTranscriberError.noActiveSession }
        guard let partial = try session.pushAudio(chunk).last else { return nil }
        guard partial.text != latestText else { return nil }
        latestText = partial.text
        return TranscriptUpdate(text: partial.text, isFinal: partial.isFinal)
    }

    public func finish() throws -> String {
        guard let session else { throw NemotronTranscriberError.noActiveSession }
        defer {
            self.session = nil
            latestText = ""
        }
        let finals = try session.finalize()
        return finals.last(where: \.isFinal)?.text ?? finals.last?.text ?? latestText
    }
}

private enum NemotronTranscriberError: LocalizedError {
    case noActiveSession

    var errorDescription: String? {
        switch self {
        case .noActiveSession:
            "Call begin(language:) before pushing or finishing a transcription session."
        }
    }
}
