import Foundation

public enum TutorLanguage: String, Sendable, CaseIterable {
    case english = "en"
    case spanish = "es"
}

public extension TutorLanguage {
    var asrLocale: String {
        switch self {
        case .english: "en-US"
        case .spanish: "es-US"
        }
    }
}

public struct TranscriptUpdate: Sendable, Equatable {
    public var text: String
    public var isFinal: Bool

    public init(text: String, isFinal: Bool) { self.text = text; self.isFinal = isFinal }
}

public struct ChatTurn: Sendable, Equatable {
    public enum Role: Sendable { case user, tutor }
    public var role: Role
    public var text: String

    public init(role: Role, text: String) { self.role = role; self.text = text }
}

public enum TutorAction: Sendable, Equatable { case show(String) }
public enum ConversationState: Sendable, Equatable { case idle, listening, thinking, speaking }

public protocol VoiceActivityDetecting: AnyObject {
    func speechProbability(_ chunk: [Float]) -> Float
    func reset()
}

public protocol TurnCompletionJudging: AnyObject {
    func completionProbability(turnAudio: [Float]) throws -> Float
}

public protocol StreamingTranscribing: AnyObject {
    func begin(language: TutorLanguage) throws
    func push(_ chunk: [Float]) throws -> TranscriptUpdate?
    func finish() throws -> String
}

public protocol TutorGenerating: Sendable {
    func reply(system: String, history: [ChatTurn]) -> AsyncThrowingStream<String, Error>
}

public protocol SpeechSynthesizing: Sendable {
    func setLanguage(_ language: TutorLanguage) async throws
    func stream(_ text: String) -> AsyncThrowingStream<[Float], Error>
}

public protocol AudioOutput: AnyObject {
    func enqueue(_ samples24k: [Float])
    func duck()
    func unduck()
    func stopAll()
    var isPlaying: Bool { get }
    var outputLatency: TimeInterval { get }
}
