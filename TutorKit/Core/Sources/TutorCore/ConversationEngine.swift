import Foundation
import os

public enum ConversationEvent: Sendable, Equatable {
    case state(ConversationState)
    case userCaption(String, isFinal: Bool)
    case tutorCaption(String)
    case action(TutorAction)
    case metrics(TurnMetrics)
    case error(String)
}

public actor ConversationEngine {
    private static let log = Logger(subsystem: "AgenticTutor", category: "conversation")
    public nonisolated let events: AsyncStream<ConversationEvent>
    private let continuation: AsyncStream<ConversationEvent>.Continuation
    private let vad: VoiceActivityDetecting
    private let judge: TurnCompletionJudging
    private let asr: StreamingTranscribing
    private let tutor: TutorGenerating
    private let tts: SpeechSynthesizing
    private let output: AudioOutput
    private let config: TurnConfig
    private let mergeWindow: TimeInterval
    private let maxHistoryTurns: Int
    private let now: @Sendable () -> TimeInterval

    private var setting: TutorLanguage
    private var turnTaker: TurnTaker
    private var state: ConversationState = .idle
    private var history: [ChatTurn] = []
    private var preRoll: [[Float]] = []
    private var turnAudio: [Float] = []
    private var asrActive = false
    private var duckActive = false
    private var sentDuckWords = false
    private var recorder = LatencyRecorder()
    private var lastTurnEndedAt: TimeInterval?
    private var mergePrefix: String?
    private var ttsLanguage: TutorLanguage?
    private var replyTask: Task<Void, Never>?
    private var replyID: UUID?
    private var replyLanguage: TutorLanguage?
    private var enqueuedSpeech: [String] = []
    private var markedTTSFirstChunk = false
    private var markedFirstEnqueue = false
    private var diagnosticChunks = 0
    private var diagnosticPeak: Float = 0
    private var diagnosticMaxVAD: Float = 0

    public init(
        vad: VoiceActivityDetecting,
        judge: TurnCompletionJudging,
        asr: StreamingTranscribing,
        tutor: TutorGenerating,
        tts: SpeechSynthesizing,
        output: AudioOutput,
        setting: TutorLanguage,
        config: TurnConfig = .init(),
        mergeWindow: TimeInterval = 2.0,
        maxHistoryTurns: Int = 12,
        now: @escaping @Sendable () -> TimeInterval
    ) {
        var captured: AsyncStream<ConversationEvent>.Continuation!
        events = AsyncStream { captured = $0 }
        continuation = captured
        self.vad = vad
        self.judge = judge
        self.asr = asr
        self.tutor = tutor
        self.tts = tts
        self.output = output
        self.setting = setting
        self.config = config
        self.turnTaker = TurnTaker(config: config)
        self.mergeWindow = mergeWindow
        self.maxHistoryTurns = max(1, maxHistoryTurns)
        self.now = now
    }

    deinit { continuation.finish() }

    public func start() {
        guard state == .idle else { return }
        turnTaker = TurnTaker(config: config)
        preRoll.removeAll(keepingCapacity: true)
        turnAudio.removeAll(keepingCapacity: true)
        diagnosticChunks = 0
        diagnosticPeak = 0
        diagnosticMaxVAD = 0
        vad.reset()
        Self.log.info("conversation started")
        emit(.state(.listening))
        state = .listening
    }

    public func stop() {
        let hadReply = replyID != nil
        replyTask?.cancel()
        replyTask = nil
        replyID = nil
        output.stopAll()
        _ = turnTaker.process(.tutorSpeaking(false))
        commitTutorIfNeeded()
        if hadReply { emit(.metrics(recorder.close(footprint: currentFootprintBytes()))) }
        asrActive = false
        duckActive = false
        turnTaker = TurnTaker(config: config)
        preRoll.removeAll(keepingCapacity: true)
        turnAudio.removeAll(keepingCapacity: true)
        Self.log.info("conversation stopped")
        emit(.state(.idle))
        state = .idle
    }

    public func ingest(micChunk16k chunk: [Float], at time: TimeInterval) {
        guard chunk.count == 512, state != .idle else { return }
        preRoll.append(chunk)
        preRoll = Array(preRoll.suffix(max(config.onsetChunks + 2, 4)))
        if asrActive { push(chunk, at: time) }
        let probability = vad.speechProbability(chunk)
        diagnosticChunks += 1
        diagnosticPeak = max(diagnosticPeak, chunk.reduce(Float.zero) { max($0, abs($1)) })
        diagnosticMaxVAD = max(diagnosticMaxVAD, probability)
        if diagnosticChunks >= 64 {
            let lagMilliseconds = (now() - time) * 1_000
            Self.log.info("mic: 64 chunks; peak=\(self.diagnosticPeak) maxVAD=\(self.diagnosticMaxVAD) lagMs=\(lagMilliseconds)")
            diagnosticChunks = 0
            diagnosticPeak = 0
            diagnosticMaxVAD = 0
        }
        process(turnTaker.process(.vad(probability, at: time)), at: time)
    }

    public func setHold(_ held: Bool, at time: TimeInterval) {
        process(turnTaker.process(.hold(held, at: time)), at: time)
    }

    public func setLanguageSetting(_ language: TutorLanguage) { setting = language }

    public func submitTyped(_ text: String) {
        let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return }
        if state == .thinking || state == .speaking { interruptReply() }
        beginFinishedTurn(cleaned, at: now(), merge: false)
    }

    private func process(_ outputs: [TurnOutput], at time: TimeInterval) {
        for item in outputs {
            switch item {
            case let .userSpeechStarted(at: onset): startUserTurn(at: onset)
            case let .checkTurn(at: checkTime):
                do {
                    let probability = try judge.completionProbability(turnAudio: turnAudio)
                    process(turnTaker.process(.verdict(probability, at: checkTime)), at: checkTime)
                } catch { fail(error) }
            case let .turnEnded(at: endedAt, reason: _, silenceAllowance: allowance): finishASR(at: endedAt, allowance: allowance)
            case let .duckTutor(at: duckAt):
                duckActive = true
                sentDuckWords = false
                output.duck()
                recorder.mark(.duck, at: duckAt)
            case .unduckTutor:
                duckActive = false
                output.unduck()
            case .bargeIn:
                interruptReply()
            }
        }
    }

    private func startUserTurn(at onset: TimeInterval) {
        Self.log.info("speech detected; starting transcription")
        let shouldMerge = lastTurnEndedAt.map { onset - $0 < mergeWindow } ?? false
        if shouldMerge, let prior = history.lastIndex(where: { $0.role == .user }) {
            mergePrefix = history[prior].text
            history.removeSubrange(prior..<history.endIndex)
        } else {
            mergePrefix = nil
        }
        turnAudio = []
        do {
            try asr.begin(language: setting)
            asrActive = true
            for chunk in preRoll { push(chunk, at: onset) }
            recorder.mark(.speechOnset, at: onset)
        } catch { failASR(error) }
    }

    private func push(_ chunk: [Float], at time: TimeInterval) {
        guard asrActive else { return }
        turnAudio.append(contentsOf: chunk)
        do {
            guard let update = try asr.push(chunk) else { return }
            emit(.userCaption(update.text, isFinal: update.isFinal))
            if duckActive && !sentDuckWords && !update.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                sentDuckWords = true
                process(turnTaker.process(.asrWords(at: time)), at: time)
            }
        } catch { failASR(error) }
    }

    private func finishASR(at time: TimeInterval, allowance: TimeInterval) {
        guard asrActive else { return }
        Self.log.info("turn ended; finalizing transcription; silenceSeconds=\(allowance)")
        asrActive = false
        lastTurnEndedAt = time
        do {
            let final = try asr.finish().trimmingCharacters(in: .whitespacesAndNewlines)
            Self.log.info("transcription finalized; characters=\(final.count)")
            recorder.mark(.turnEnded(silenceAllowance: allowance), at: time)
            recorder.mark(.asrFinal, at: now())
            guard !final.isEmpty else { emit(.state(.listening)); state = .listening; return }
            emit(.userCaption(final, isFinal: true))
            let combined = [mergePrefix, final].compactMap { $0 }.joined(separator: " ")
            mergePrefix = nil
            beginFinishedTurn(combined, at: time, merge: false)
        } catch { failASR(error) }
    }

    private func beginFinishedTurn(_ text: String, at time: TimeInterval, merge: Bool) {
        let language = LanguagePolicy.replyLanguage(for: text, setting: setting)
        Self.log.info("generating reply; language=\(language.rawValue, privacy: .public)")
        history.append(ChatTurn(role: .user, text: text))
        let retained = Array(history.suffix(maxHistoryTurns))
        emit(.state(.thinking))
        state = .thinking
        let id = UUID()
        replyID = id
        replyLanguage = language
        enqueuedSpeech = []
        markedTTSFirstChunk = false
        markedFirstEnqueue = false
        replyTask = Task { [weak self] in await self?.runReply(id: id, language: language, history: retained) }
    }

    private func runReply(id: UUID, language: TutorLanguage, history: [ChatTurn]) async {
        var parser = ReplyStreamParser()
        var sawToken = false
        do {
            for try await chunk in tutor.reply(system: TutorPrompt.system(for: language), history: history) {
                guard !Task.isCancelled, replyID == id else { return }
                if !sawToken {
                    sawToken = true
                    recorder.mark(.llmFirstToken, at: now())
                    Self.log.info("first reply token")
                }
                try await speak(parser.feed(chunk), id: id, language: language)
            }
            guard !Task.isCancelled, replyID == id else { return }
            try await speak(parser.finish(), id: id, language: language)
            guard !Task.isCancelled, replyID == id else { return }
            await finishReply(id: id)
        } catch is CancellationError {
            return
        } catch { fail(error, id: id) }
    }

    private func speak(_ pieces: [ReplyPiece], id: UUID, language: TutorLanguage) async throws {
        for piece in pieces {
            guard !Task.isCancelled, replyID == id else { return }
            switch piece {
            case let .action(action): emit(.action(action))
            case let .speech(text):
                let spoken = SpokenMath.speakable(text, language: language)
                if ttsLanguage != language { try await tts.setLanguage(language); ttsLanguage = language }
                var enqueued = false
                for try await audio in tts.stream(spoken) {
                    guard !Task.isCancelled, replyID == id else { return }
                    if !enqueued {
                        if !markedTTSFirstChunk {
                            recorder.mark(.ttsFirstChunk, at: now())
                            markedTTSFirstChunk = true
                            Self.log.info("first synthesized audio")
                        }
                        enqueued = true
                    }
                    output.enqueue(audio)
                    if !markedFirstEnqueue {
                        recorder.mark(.firstEnqueue(outputLatency: output.outputLatency), at: now())
                        markedFirstEnqueue = true
                    }
                    if state != .speaking {
                        _ = turnTaker.process(.tutorSpeaking(true))
                        emit(.state(.speaking)); state = .speaking
                    }
                }
                if enqueued { enqueuedSpeech.append(text); emit(.tutorCaption(text)) }
            }
        }
    }

    private func interruptReply() {
        let id = replyID
        replyTask?.cancel()
        replyTask = nil
        replyID = nil
        output.stopAll()
        _ = turnTaker.process(.tutorSpeaking(false))
        commitTutorIfNeeded()
        if id != nil { emit(.metrics(recorder.close(footprint: currentFootprintBytes()))) }
        emit(.state(.listening)); state = .listening
    }

    private func finishReply(id: UUID) async {
        guard replyID == id else { return }
        commitTutorIfNeeded()
        while output.isPlaying {
            do {
                try await Task.sleep(for: .milliseconds(50))
            } catch {
                return
            }
            guard !Task.isCancelled, replyID == id else { return }
        }
        guard !Task.isCancelled, replyID == id else { return }
        replyTask = nil
        replyID = nil
        emit(.metrics(recorder.close(footprint: currentFootprintBytes())))
        _ = turnTaker.process(.tutorSpeaking(false))
        emit(.state(.listening))
        state = .listening
    }

    private func commitTutorIfNeeded() {
        guard !enqueuedSpeech.isEmpty else { return }
        history.append(ChatTurn(role: .tutor, text: enqueuedSpeech.joined(separator: " ")))
        enqueuedSpeech = []
    }

    private func fail(_ error: Error, id: UUID? = nil) {
        guard id == nil || replyID == id else { return }
        Self.log.error("conversation error: \(error.localizedDescription, privacy: .public)")
        let hadReply = replyID != nil
        replyTask?.cancel()
        replyTask = nil
        replyID = nil
        output.stopAll()
        _ = turnTaker.process(.tutorSpeaking(false))
        commitTutorIfNeeded()
        if hadReply { emit(.metrics(recorder.close(footprint: currentFootprintBytes()))) }
        emit(.error(error.localizedDescription))
        emit(.state(.listening)); state = .listening
    }

    private func failASR(_ error: Error) {
        asrActive = false
        turnAudio.removeAll(keepingCapacity: true)
        preRoll.removeAll(keepingCapacity: true)
        turnTaker = TurnTaker(config: config)
        fail(error)
    }

    private func emit(_ event: ConversationEvent) { continuation.yield(event) }
}
