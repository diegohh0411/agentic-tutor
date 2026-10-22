import MLXHuggingFace
import MLXLLM
import MLXLMCommon
import TutorCore

/// Adapts a local Qwen MLX model to the tutoring generation port.
///
/// A new `ChatSession` is made for each reply because `ConversationEngine`
/// supplies the complete capped history on every call. This avoids appending
/// that history to a session cache a second time.
public final class QwenTutor: TutorGenerating, @unchecked Sendable {
    private let modelContainer: ModelContainer

    private init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
    }

    /// Downloads the model on first use, then loads it for local MLX inference.
    public static func load(modelId: String) async throws -> QwenTutor {
        // In mlx-swift-lm 3.31.4 this macro expands to the package's default
        // Hugging Face downloader and tokenizer loader.
        let modelContainer = try await #huggingFaceLoadModelContainer(
            configuration: ModelConfiguration(id: modelId)
        )
        return QwenTutor(modelContainer: modelContainer)
    }

    public func reply(
        system: String,
        history: [ChatTurn]
    ) -> AsyncThrowingStream<String, Error> {
        let messages: [Chat.Message] = [.system(system)] + history.map { turn in
            switch turn.role {
            case .user:
                .user(turn.text)
            case .tutor:
                .assistant(turn.text)
            }
        }
        let session = ChatSession(
            modelContainer,
            generateParameters: GenerateParameters(maxTokens: 300, temperature: 0.6),
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
