import Foundation
@testable import TutorCore

final class VADFake: VoiceActivityDetecting {
    private let lock = NSLock()
    private var probabilities: [Float]
    private let fallback: Float

    init(probabilities: [Float], fallback: Float = 0) {
        self.probabilities = probabilities
        self.fallback = fallback
    }

    func speechProbability(_: [Float]) -> Float {
        lock.withLock { probabilities.isEmpty ? fallback : probabilities.removeFirst() }
    }

    func reset() {}
}

final class JudgeFake: TurnCompletionJudging {
    private let lock = NSLock()
    var probability: Float
    private var audioLog: [[Float]] = []

    init(probability: Float = 1) { self.probability = probability }

    var turnAudios: [[Float]] { lock.withLock { audioLog } }

    func completionProbability(turnAudio: [Float]) throws -> Float {
        lock.withLock { audioLog.append(turnAudio) }
        return probability
    }
}

final class ASRFake: StreamingTranscribing {
    private let lock = NSLock()
    private var texts: [String]
    private let partialText: String
    private var beginCount = 0
    private var pushesBySession: [[Int]] = []
    private var shouldThrowOnPush: Bool

    init(texts: [String], partialText: String = "words", throwOnFirstPush: Bool = false) {
        self.texts = texts
        self.partialText = partialText
        shouldThrowOnPush = throwOnFirstPush
    }

    var begins: Int { lock.withLock { beginCount } }
    var pushesPerSession: [[Int]] { lock.withLock { pushesBySession } }

    func begin(language _: TutorLanguage) throws {
        lock.withLock {
            beginCount += 1
            pushesBySession.append([])
        }
    }

    func push(_ samples: [Float]) throws -> TranscriptUpdate? {
        let shouldThrow = lock.withLock { () -> Bool in
            pushesBySession[pushesBySession.count - 1].append(samples.count)
            defer { shouldThrowOnPush = false }
            return shouldThrowOnPush
        }
        if shouldThrow { throw FakeError.asr }
        return TranscriptUpdate(text: partialText, isFinal: false)
    }

    func finish() throws -> String {
        lock.withLock { texts.isEmpty ? "" : texts.removeFirst() }
    }
}

struct TutorCall: Equatable {
    let system: String
    let history: [ChatTurn]
}

final class TutorFake: TutorGenerating, @unchecked Sendable {
    private let lock = NSLock()
    private var scripts: [[String]]
    private let delay: TimeInterval
    private let shouldThrow: Bool
    private var cancelled = false
    private var callLog: [TutorCall] = []

    init(scripts: [[String]], delay: TimeInterval = 0, shouldThrow: Bool = false) {
        self.scripts = scripts
        self.delay = delay
        self.shouldThrow = shouldThrow
    }

    var calls: [TutorCall] { lock.withLock { callLog } }
    var wasCancelled: Bool { lock.withLock { cancelled } }

    func reply(system: String, history: [ChatTurn]) -> AsyncThrowingStream<String, Error> {
        let script = lock.withLock { () -> [String] in
            callLog.append(TutorCall(system: system, history: history))
            return scripts.isEmpty ? [] : scripts.removeFirst()
        }

        return AsyncThrowingStream { continuation in
            let producer = Task { [weak self] in
                guard let self else { return }
                if self.shouldThrow {
                    continuation.finish(throwing: FakeError.tutor)
                    return
                }
                do {
                    for (index, chunk) in script.enumerated() {
                        if index > 0, self.delay > 0 {
                            try await Task.sleep(for: .milliseconds(Int(self.delay * 1_000)))
                        }
                        try Task.checkCancellation()
                        continuation.yield(chunk)
                    }
                    continuation.finish()
                } catch is CancellationError {
                    self.lock.withLock { self.cancelled = true }
                    continuation.finish(throwing: CancellationError())
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { [weak self] termination in
                if case .cancelled = termination {
                    self?.lock.withLock { self?.cancelled = true }
                    producer.cancel()
                }
            }
        }
    }
}

final class TTSFake: SpeechSynthesizing, @unchecked Sendable {
    private let lock = NSLock()
    private var currentLanguage: TutorLanguage?
    private var languageLog: [TutorLanguage] = []
    private var textLog: [String] = []
    private var streamLanguageLog: [TutorLanguage?] = []

    var languages: [TutorLanguage] { lock.withLock { languageLog } }
    var texts: [String] { lock.withLock { textLog } }
    var streamLanguages: [TutorLanguage?] { lock.withLock { streamLanguageLog } }

    func setLanguage(_ language: TutorLanguage) async throws {
        lock.withLock {
            currentLanguage = language
            languageLog.append(language)
        }
    }

    func stream(_ text: String) -> AsyncThrowingStream<[Float], Error> {
        let language = lock.withLock { () -> TutorLanguage? in
            textLog.append(text)
            streamLanguageLog.append(currentLanguage)
            return currentLanguage
        }
        _ = language
        return AsyncThrowingStream { continuation in
            continuation.yield([Float](repeating: 0, count: 2_400))
            continuation.finish()
        }
    }
}

enum OutputCall: Equatable {
    case enqueue(Int)
    case duck
    case unduck
    case stopAll
}

final class OutputFake: AudioOutput {
    private let lock = NSLock()
    private var callLog: [OutputCall] = []
    private let playbackDuration: TimeInterval
    private var playbackEndsAt: Date?
    var outputLatency: TimeInterval = 0

    init(playbackDuration: TimeInterval = 0) {
        self.playbackDuration = playbackDuration
    }

    var calls: [OutputCall] { lock.withLock { callLog } }
    var isPlaying: Bool {
        lock.withLock {
            guard let playbackEndsAt else { return false }
            return Date() < playbackEndsAt
        }
    }

    func enqueue(_ samples24k: [Float]) {
        lock.withLock {
            callLog.append(.enqueue(samples24k.count))
            if playbackDuration > 0 { playbackEndsAt = Date().addingTimeInterval(playbackDuration) }
        }
    }
    func duck() { lock.withLock { callLog.append(.duck) } }
    func unduck() { lock.withLock { callLog.append(.unduck) } }
    func stopAll() { lock.withLock { callLog.append(.stopAll) } }
}

final class TestClock: @unchecked Sendable {
    private let lock = NSLock()
    private var value: TimeInterval

    init(_ value: TimeInterval = 0) { self.value = value }
    func now() -> TimeInterval { lock.withLock { value } }
    func set(_ value: TimeInterval) { lock.withLock { self.value = value } }
}

actor EventLog {
    private var values: [ConversationEvent] = []

    func append(_ event: ConversationEvent) { values.append(event) }
    func snapshot() -> [ConversationEvent] { values }
}

enum FakeError: Error { case tutor, asr }
