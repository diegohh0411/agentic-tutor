import SpeechVAD
import TutorCore

/// Adapts speech-swift's stateful Silero model to the tutor's fixed-frame VAD port.
///
/// `SileroVADModel` is not thread-safe. The owning `ConversationEngine` actor calls
/// this adapter serially, including when it resets a stream between conversations.
public final class SileroVAD: VoiceActivityDetecting {
    public static let chunkSize = SileroVADModel.chunkSize

    private let model: SileroVADModel

    private init(model: SileroVADModel) {
        self.model = model
    }

    /// Downloads (on first use) and loads Silero's Core ML model.
    public static func load() async throws -> SileroVAD {
        let model = try await SileroVADModel.fromPretrained(engine: .coreml)
        return SileroVAD(model: model)
    }

    public func speechProbability(_ chunk: [Float]) -> Float {
        model.processChunk(chunk)
    }

    public func reset() {
        model.resetState()
    }
}
