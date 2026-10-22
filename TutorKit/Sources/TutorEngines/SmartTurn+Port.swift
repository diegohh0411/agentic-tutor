import SpeechVAD
import TutorCore

/// Adapts speech-swift's Smart Turn end-of-turn classifier to TutorCore.
///
/// `SmartTurnModel` is not thread-safe. The owning `ConversationEngine` actor calls
/// this adapter serially.
public final class SmartTurnJudge: TurnCompletionJudging {
    private let model: SmartTurnModel

    private init(model: SmartTurnModel) {
        self.model = model
    }

    /// Downloads (on first use), loads, and warms the Smart Turn Core ML graph.
    ///
    /// With `offline` the cached copy is loaded without contacting the network.
    public static func load(
        offline: Bool = false,
        progress: (@Sendable (Double) -> Void)? = nil
    ) async throws -> SmartTurnJudge {
        let model = try await SmartTurnModel.fromPretrained(
            offlineMode: offline,
            progressHandler: progress.map { report in { fraction, _ in report(fraction) } }
        )
        try model.prewarm()
        return SmartTurnJudge(model: model)
    }

    public func completionProbability(turnAudio: [Float]) throws -> Float {
        try model.turnCompleteProbability(audio: turnAudio, sampleRate: 16_000)
    }
}
