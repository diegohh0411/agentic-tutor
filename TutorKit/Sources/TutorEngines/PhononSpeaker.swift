import Foundation
import PhononTTS
import TutorCore

/// A streaming Phonon adapter for the tutor's speech-synthesis port.
public final class PhononSpeaker: SpeechSynthesizing, @unchecked Sendable {
    public static let sampleRate: Double = 24_000

    /// The voices included in the installed model bundle.
    public let voices: [String]

    private let phonon: Phonon
    private let configuration: Configuration

    private init(phonon: Phonon) {
        self.phonon = phonon
        voices = phonon.voices
        configuration = Configuration(phonon: phonon)
    }

    /// Installs a bundled export in Application Support and loads it for streaming synthesis.
    public static func load(bundledModels: URL) async throws -> PhononSpeaker {
        let installedModels = try PhononModels.install(bundled: bundledModels)
        let phonon = try await Phonon.load(models: installedModels, language: .english)
        return PhononSpeaker(phonon: phonon)
    }

    /// Selects the catalog voice and Phonon's text normalization for a changed tutor language.
    public func setLanguage(_ language: TutorLanguage) async throws {
        try await configuration.setLanguage(language)
    }

    /// Selects an explicit model voice for a language.
    ///
    /// This is used by the listening probe to audition every tagged model voice before the
    /// catalog's English and Mexican Spanish selections are finalized.
    public func selectVoice(_ voice: String, language: TutorLanguage) async throws {
        try await configuration.selectVoice(voice, language: language)
    }

    /// Streams 24 kHz mono Float32 samples and cancels Phonon's producer when consumption ends.
    public func stream(_ text: String) -> AsyncThrowingStream<[Float], Error> {
        AsyncThrowingStream { continuation in
            let producer = Task {
                do {
                    for try await samples in self.phonon.stream(text) {
                        guard !Task.isCancelled else { break }
                        continuation.yield(samples)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }

            continuation.onTermination = { _ in
                producer.cancel()
            }
        }
    }

    private actor Configuration {
        private let phonon: Phonon
        private var language: TutorLanguage?

        init(phonon: Phonon) {
            self.phonon = phonon
        }

        func setLanguage(_ language: TutorLanguage) async throws {
            guard language != self.language else { return }
            try await phonon.setLanguage(phononLanguage(for: language))
            try await phonon.setVoice(catalogVoice(for: language))
            self.language = language
        }

        func selectVoice(_ voice: String, language: TutorLanguage) async throws {
            if language != self.language {
                try await phonon.setLanguage(phononLanguage(for: language))
                self.language = language
            }
            try await phonon.setVoice(voice)
        }

        private func phononLanguage(for language: TutorLanguage) -> Language {
            switch language {
            case .english: .english
            case .spanish: .spanish
            }
        }

        private func catalogVoice(for language: TutorLanguage) -> String {
            switch language {
            case .english: ModelCatalog.phononVoiceEnglish
            case .spanish: ModelCatalog.phononVoiceSpanish
            }
        }
    }
}
