import Foundation
import Testing
@testable import TutorCore

private let frame = [Float](repeating: 0, count: 512)

private func testConfig() -> TurnConfig {
    var config = TurnConfig()
    config.pauseTrigger = 0.032
    config.recheckInterval = 0.032
    config.confirmCount = 1
    return config
}

private func eventually(
    timeout: TimeInterval = 1,
    _ condition: @escaping @Sendable () async -> Bool
) async -> Bool {
    let deadline = Date().addingTimeInterval(timeout)
    while Date() < deadline {
        if await condition() { return true }
        try? await Task.sleep(for: .milliseconds(10))
    }
    return await condition()
}

private func collectEvents(from engine: ConversationEngine, into log: EventLog) -> Task<Void, Never> {
    Task {
        for await event in engine.events {
            await log.append(event)
        }
    }
}

private func makeEngine(
    vad: VADFake,
    asr: ASRFake,
    tutor: TutorFake,
    tts: TTSFake = TTSFake(),
    output: OutputFake = OutputFake(),
    judge: JudgeFake = JudgeFake(),
    setting: TutorLanguage = .english,
    clock: TestClock = TestClock()
) -> ConversationEngine {
    ConversationEngine(
        vad: vad,
        judge: judge,
        asr: asr,
        tutor: tutor,
        tts: tts,
        output: output,
        setting: setting,
        config: testConfig(),
        now: { clock.now() }
    )
}

private func submitFinishedVoiceTurn(to engine: ConversationEngine, at start: TimeInterval) async {
    await engine.ingest(micChunk16k: frame, at: start)
    await engine.ingest(micChunk16k: frame, at: start + 0.032)
    await engine.ingest(micChunk16k: frame, at: start + 0.064)
    await engine.ingest(micChunk16k: frame, at: start + 0.096)
}

@Test func endToEndReplySpeaksNormalizedPhrases() async {
    let vad = VADFake(probabilities: [0.9, 0.9, 0, 0])
    let asr = ASRFake(texts: ["what is three quarters"])
    let tutor = TutorFake(scripts: [["Look: <show>3/4</show> ", "That is 3/4 of it."]])
    let tts = TTSFake()
    let engine = makeEngine(vad: vad, asr: asr, tutor: tutor, tts: tts)
    let events = EventLog()
    let collector = collectEvents(from: engine, into: events)
    defer { collector.cancel() }

    await engine.start()
    await submitFinishedVoiceTurn(to: engine, at: 0)

    #expect(await eventually { tts.texts == ["Look:", "That is three quarters of it."] })
    #expect(await eventually {
        let states = await events.snapshot().compactMap { event -> ConversationState? in
            guard case let .state(state) = event else { return nil }
            return state
        }
        return states == [.listening, .thinking, .speaking, .listening]
    })
    let recorded = await events.snapshot()
    #expect(recorded.contains(.action(.show("3/4"))))
    #expect(recorded.compactMap { event -> ConversationState? in
        guard case let .state(state) = event else { return nil }
        return state
    } == [.listening, .thinking, .speaking, .listening])
}

@Test func bargeInStopsAndCancels() async {
    let vad = VADFake(probabilities: Array(repeating: 0.9, count: 13))
    let asr = ASRFake(texts: [])
    let tutor = TutorFake(
        scripts: [["This first response is long enough.", " A delayed second sentence." ]],
        delay: 0.3
    )
    let tts = TTSFake()
    let output = OutputFake()
    let engine = makeEngine(vad: vad, asr: asr, tutor: tutor, tts: tts, output: output)
    await engine.start()
    await engine.submitTyped("first question")
    #expect(await eventually { output.calls.contains(.enqueue(2_400)) })

    for index in 0 ..< 13 {
        await engine.ingest(micChunk16k: frame, at: 1 + (Double(index) * 0.032))
    }

    #expect(await eventually { output.calls.contains(.duck) && output.calls.contains(.stopAll) })
    #expect(await eventually { tutor.wasCancelled })

    await engine.submitTyped("next question")
    #expect(await eventually { tutor.calls.count == 2 })
    if tutor.calls.count == 2 {
        #expect(tutor.calls[1].history.contains(ChatTurn(role: .tutor, text: "This first response is long enough.")))
    }
}

@Test func earlyCutoffMergesTurns() async {
    let vad = VADFake(probabilities: [0.9, 0.9, 0, 0, 0.9, 0.9, 0, 0])
    let asr = ASRFake(texts: ["what is seven", "times eight"])
    let tutor = TutorFake(scripts: [["First reply."], ["Second reply."]])
    let engine = makeEngine(vad: vad, asr: asr, tutor: tutor)
    await engine.start()
    await submitFinishedVoiceTurn(to: engine, at: 0)
    #expect(await eventually { tutor.calls.count == 1 })

    await submitFinishedVoiceTurn(to: engine, at: 1)
    #expect(await eventually { tutor.calls.count == 2 })
    if tutor.calls.count == 2 {
        #expect(tutor.calls[1].history == [ChatTurn(role: .user, text: "what is seven times eight")])
    }
}

@Test func typedInputWhileSpeakingInterrupts() async {
    let vad = VADFake(probabilities: [0.9, 0.9, 0, 0])
    let asr = ASRFake(texts: ["first question"])
    let tutor = TutorFake(
        scripts: [["This first response is long enough.", " More later."], ["The new reply is ready."]],
        delay: 0.3
    )
    let output = OutputFake()
    let engine = makeEngine(vad: vad, asr: asr, tutor: tutor, output: output)
    await engine.start()
    await submitFinishedVoiceTurn(to: engine, at: 0)
    #expect(await eventually { output.calls.contains(.enqueue(2_400)) })

    await engine.submitTyped("and 9 times 9?")

    #expect(await eventually { tutor.calls.count == 2 })
    #expect(output.calls.contains(.stopAll))
    if tutor.calls.count == 2 {
        #expect(tutor.calls[1].history.last == ChatTurn(role: .user, text: "and 9 times 9?"))
    }
}

@Test func historyIsCappedAtTwelveTurns() async {
    let tutor = TutorFake(scripts: Array(repeating: ["This response is long enough."], count: 10))
    let engine = makeEngine(vad: VADFake(probabilities: []), asr: ASRFake(texts: []), tutor: tutor)
    let events = EventLog()
    let collector = collectEvents(from: engine, into: events)
    defer { collector.cancel() }
    await engine.start()

    for turn in 1 ... 10 {
        await engine.submitTyped("question \(turn)")
        #expect(await eventually { tutor.calls.count == turn })
        #expect(await eventually {
            let states = await events.snapshot().compactMap { event -> ConversationState? in
                guard case let .state(state) = event else { return nil }
                return state
            }
            return states.filter { $0 == .listening }.count == turn + 1
        })
    }

    let expected = [
        ChatTurn(role: .tutor, text: "This response is long enough."),
        ChatTurn(role: .user, text: "question 5"),
        ChatTurn(role: .tutor, text: "This response is long enough."),
        ChatTurn(role: .user, text: "question 6"),
        ChatTurn(role: .tutor, text: "This response is long enough."),
        ChatTurn(role: .user, text: "question 7"),
        ChatTurn(role: .tutor, text: "This response is long enough."),
        ChatTurn(role: .user, text: "question 8"),
        ChatTurn(role: .tutor, text: "This response is long enough."),
        ChatTurn(role: .user, text: "question 9"),
        ChatTurn(role: .tutor, text: "This response is long enough."),
        ChatTurn(role: .user, text: "question 10"),
    ]
    #expect(tutor.calls.last?.history == expected)
}

@Test func smartTurnAudioHasNoDuplicatedPreRoll() async {
    let first = [Float](repeating: 1, count: 512)
    let second = [Float](repeating: 2, count: 512)
    let judge = JudgeFake()
    let engine = makeEngine(
        vad: VADFake(probabilities: [0.9, 0.9, 0]),
        asr: ASRFake(texts: ["done"]),
        tutor: TutorFake(scripts: [[]]),
        judge: judge
    )
    await engine.start()

    await engine.ingest(micChunk16k: first, at: 0)
    await engine.ingest(micChunk16k: second, at: 0.032)
    await engine.ingest(micChunk16k: frame, at: 0.064)

    #expect(await eventually { !judge.turnAudios.isEmpty })
    let actualTurnAudio = first + second + frame
    #expect(judge.turnAudios.first?.count == actualTurnAudio.count)
    #expect(judge.turnAudios.first == actualTurnAudio)
}

@Test func asrErrorResetsSession() async {
    let asr = ASRFake(texts: [], throwOnFirstPush: true)
    let engine = makeEngine(
        vad: VADFake(probabilities: [0.9, 0.9, 0.9, 0.9]),
        asr: asr,
        tutor: TutorFake(scripts: [])
    )
    let events = EventLog()
    let collector = collectEvents(from: engine, into: events)
    defer { collector.cancel() }
    await engine.start()

    await engine.ingest(micChunk16k: frame, at: 0)
    await engine.ingest(micChunk16k: frame, at: 0.032)
    #expect(await eventually { asr.begins == 1 })
    #expect(await eventually {
        let recorded = await events.snapshot()
        return recorded.contains { if case .error = $0 { return true }; return false }
            && recorded.last == .state(.listening)
    })
    let failedSessionPushes = asr.pushesPerSession[0]

    await engine.ingest(micChunk16k: frame, at: 1)
    await engine.ingest(micChunk16k: frame, at: 1.032)

    #expect(await eventually { asr.begins == 2 })
    #expect(asr.pushesPerSession[0] == failedSessionPushes)
    #expect(asr.pushesPerSession[1] == [512, 512])
}

@Test func waitsForPlaybackBeforeListening() async {
    let output = OutputFake(playbackDuration: 0.15)
    let tutor = TutorFake(scripts: [["Playback is still draining."]])
    let engine = makeEngine(vad: VADFake(probabilities: []), asr: ASRFake(texts: []), tutor: tutor, output: output)
    let events = EventLog()
    let collector = collectEvents(from: engine, into: events)
    defer { collector.cancel() }
    await engine.start()
    await engine.submitTyped("test playback")

    #expect(await eventually { output.isPlaying })
    try? await Task.sleep(for: .milliseconds(75))
    let earlyStates = await events.snapshot().compactMap { event -> ConversationState? in
        guard case let .state(state) = event else { return nil }
        return state
    }
    #expect(earlyStates == [.listening, .thinking, .speaking])

    #expect(await eventually {
        let states = await events.snapshot().compactMap { event -> ConversationState? in
            guard case let .state(state) = event else { return nil }
            return state
        }
        return !output.isPlaying && states == [.listening, .thinking, .speaking, .listening]
    })
}

@Test func spanishTurnSwitchesVoice() async {
    let vad = VADFake(probabilities: [0.9, 0.9, 0, 0])
    let asr = ASRFake(texts: ["¿cuánto es siete por ocho, maestro?"])
    let tutor = TutorFake(scripts: [["La respuesta es cincuenta y seis."]])
    let tts = TTSFake()
    let engine = makeEngine(vad: vad, asr: asr, tutor: tutor, tts: tts)
    await engine.start()
    await submitFinishedVoiceTurn(to: engine, at: 0)

    #expect(await eventually { !tts.texts.isEmpty })
    #expect(tts.languages.first == .spanish)
    #expect(tts.streamLanguages.first == .spanish)
}

@Test func portErrorReturnsToListening() async {
    let vad = VADFake(probabilities: [0.9, 0.9, 0, 0])
    let asr = ASRFake(texts: ["what is two plus two"])
    let tutor = TutorFake(scripts: [[]], shouldThrow: true)
    let engine = makeEngine(vad: vad, asr: asr, tutor: tutor)
    let events = EventLog()
    let collector = collectEvents(from: engine, into: events)
    defer { collector.cancel() }

    await engine.start()
    await submitFinishedVoiceTurn(to: engine, at: 0)

    #expect(await eventually {
        let recorded = await events.snapshot()
        return recorded.contains { if case .error = $0 { return true }; return false }
            && recorded.contains(.state(.listening))
    })
}
