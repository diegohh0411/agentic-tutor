import Foundation
import MLXLLM
import MLXLMCommon
import TutorCore

/// Adapts a local Qwen MLX model to the tutoring generation port.
///
/// A new `ChatSession` is made for each reply because `ConversationEngine`
/// supplies the complete capped history on every call. This avoids appending
/// that history to a session cache a second time.
public final class QwenTutor: TutorGenerating, @unchecked Sendable {
    public static let temperature: Float = 0.6
    public static let maxTokens = 300

    private let modelContainer: ModelContainer

    private init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
    }

    /// Downloads the model on first use, then loads it for local MLX inference.
    ///
    /// With `localFilesOnly` the model is resolved from the on-disk Hugging Face cache and the
    /// network is never contacted. (Without it, a "main" revision is always checked against
    /// the Hub first, even when cached.)
    public static func load(
        modelId: String,
        localFilesOnly: Bool = false,
        progress: @escaping @Sendable (Double) -> Void = { _ in }
    ) async throws -> QwenTutor {
        let container = try await loadModelContainer(
            from: HubModelDownloader(localFilesOnly: localFilesOnly),
            using: HubTokenizerLoader(),
            id: modelId,
            progressHandler: { progress($0.fractionCompleted) }
        )
        return QwenTutor(modelContainer: container)
    }

    public func reply(
        system: String,
        history: [ChatTurn]
    ) -> AsyncThrowingStream<String, Error> {
        let messages: [Chat.Message] = history.map { turn in
            switch turn.role {
            case .user:
                .user(turn.text)
            case .tutor:
                .assistant(turn.text)
            }
        }
        let session = ChatSession(
            modelContainer,
            instructions: system,
            generateParameters: GenerateParameters(maxTokens: Self.maxTokens, temperature: Self.temperature),
            additionalContext: ["enable_thinking": false]
        )

        // ChatSession forwards stream termination to its generation task, so
        // cancelling this consumer also cancels MLX generation.
        return session.streamResponse(to: messages)
    }

    /// Counts generated text with the loaded model's tokenizer for probe telemetry.
    func generatedTokenCount(in text: String) async -> Int {
        await modelContainer.perform { context in
            context.tokenizer.encode(text: text, addSpecialTokens: false).count
        }
    }
}
