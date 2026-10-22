import AVFoundation
import Foundation
import Observation
import TutorAudio
import TutorCore
import TutorEngines

@Observable @MainActor
final class AppModel {
    enum Phase: Equatable {
        case setup(progress: Double, title: String)
        case ready
        case failed(String)
    }

    private static let languageKey = "language"
    private static let echoProbePhrase = "This is a short echo test. One, two, three."

    var phase: Phase = .setup(progress: 0, title: "")
    var state: ConversationState = .idle
    var userCaption = ""
    var tutorCaption = ""
    var expression: String?
    var lastMetrics: TurnMetrics?
    var needsHeadphones = false
    var micDenied = false
    var isHolding = false
    var errorMessage: String?
    var showTimingPanel = false
    /// True when the models were already installed at launch, so loading is a quick local step.
    private(set) var wasInstalledAtLaunch = ModelInstaller.isInstalled

    /// The language setting, persisted in UserDefaults under "language". Defaults to English.
    var language: TutorLanguage {
        didSet {
            UserDefaults.standard.set(language.rawValue, forKey: Self.languageKey)
            guard let engine else { return }
            let language = language
            Task { await engine.setLanguageSetting(language) }
        }
    }

    var isRunning: Bool { state != .idle }

    private var engines: LoadedEngines?
    private var engine: ConversationEngine?
    private var io: AudioIO?
    private var didRunEchoTest = false
    private var eventsTask: Task<Void, Never>?
    private var micTask: Task<Void, Never>?
    private var isStarting = false

    init() {
        let stored = UserDefaults.standard.string(forKey: Self.languageKey)
        language = stored.flatMap(TutorLanguage.init(rawValue:)) ?? .english
        micDenied = AVCaptureDevice.authorizationStatus(for: .audio) == .denied
    }

    // MARK: - Models

    /// Downloads (first run) and loads every model. Safe to call again after a failure.
    func loadModels() async {
        guard engines == nil else { return }
        guard let phononModels = Bundle.main.url(forResource: "PhononModels", withExtension: nil) else {
            phase = .failed("The voice model is missing from the app.")
            return
        }
        wasInstalledAtLaunch = ModelInstaller.isInstalled
        phase = .setup(progress: 0, title: ModelInstaller.steps.first?.title ?? "")

        let (updates, continuation) = AsyncStream.makeStream(
            of: (Double, String).self, bufferingPolicy: .bufferingNewest(1))
        let progressTask = Task { [weak self] in
            for await (fraction, title) in updates {
                self?.phase = .setup(progress: fraction, title: title)
            }
        }
        defer {
            continuation.finish()
            progressTask.cancel()
        }

        do {
            engines = try await ModelInstaller.loadAll(bundledPhonon: phononModels) { fraction, title in
                continuation.yield((fraction, title))
            }
            phase = .ready
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }

    // MARK: - Conversation

    func start() async {
        guard let engines, !isStarting, !isRunning else { return }
        isStarting = true
        defer { isStarting = false }

        guard await requestMicrophoneAccess() else { return }
        errorMessage = nil

        let io: AudioIO
        if let existing = self.io {
            io = existing
        } else {
            do {
                io = try AudioIO()
            } catch AudioIOError.voiceProcessingUnavailable {
                needsHeadphones = true
                do { io = try AudioIO(voiceProcessing: false) } catch { return fail(error) }
            } catch {
                return fail(error)
            }
            self.io = io
        }

        do { try io.start() } catch { return fail(error) }

        if !didRunEchoTest {
            didRunEchoTest = true
            if await echoLeaks(io: io, engines: engines) { needsHeadphones = true }
        }

        let engine = self.engine ?? makeEngine(engines: engines, io: io)
        self.engine = engine
        await engine.setLanguageSetting(language)
        await engine.start()
    }

    func stop() {
        guard let engine, isRunning else { return }
        isHolding = false
        Task {
            await engine.stop()
            io?.stop()
        }
    }

    func send(_ text: String) {
        guard let engine, isRunning else { return }
        Task { await engine.submitTyped(text) }
    }

    func setHold(_ held: Bool) {
        guard isHolding != held else { return }
        isHolding = held
        guard let engine else { return }
        let time = ProcessInfo.processInfo.systemUptime
        Task { await engine.setHold(held, at: time) }
    }

    // MARK: - Setup helpers

    private func requestMicrophoneAccess() async -> Bool {
        let granted: Bool
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized: granted = true
        case .notDetermined: granted = await AVCaptureDevice.requestAccess(for: .audio)
        default: granted = false
        }
        micDenied = !granted
        return granted
    }

    private func echoLeaks(io: AudioIO, engines: LoadedEngines) async -> Bool {
        do {
            try await engines.tts.setLanguage(.english)
            var probe: [Float] = []
            for try await samples in engines.tts.stream(Self.echoProbePhrase) {
                probe.append(contentsOf: samples)
            }
            guard !probe.isEmpty else { return false }
            return await EchoSelfTest.run(io: io, vad: engines.vad, probe: probe)
        } catch {
            // A failed self-test must not block the conversation.
            return false
        }
    }

    private func makeEngine(engines: LoadedEngines, io: AudioIO) -> ConversationEngine {
        let engine = ConversationEngine(
            vad: engines.vad,
            judge: engines.judge,
            asr: engines.asr,
            tutor: engines.tutor,
            tts: engines.tts,
            output: io,
            setting: language,
            now: { ProcessInfo.processInfo.systemUptime }
        )

        // Mic chunks arrive on the audio thread; one consumer keeps them in order.
        let (chunks, continuation) = AsyncStream.makeStream(
            of: ([Float], TimeInterval).self, bufferingPolicy: .unbounded)
        io.onMicChunk = { @Sendable chunk, time in continuation.yield((chunk, time)) }
        micTask = Task.detached {
            for await (chunk, time) in chunks {
                await engine.ingest(micChunk16k: chunk, at: time)
            }
        }
        eventsTask = Task { [weak self] in
            for await event in engine.events { self?.handle(event) }
        }
        return engine
    }

    private func handle(_ event: ConversationEvent) {
        switch event {
        case let .state(newState):
            state = newState
            if newState == .thinking {
                tutorCaption = ""
                expression = nil
            }
        case let .userCaption(text, _):
            userCaption = text
        case let .tutorCaption(text):
            tutorCaption = tutorCaption.isEmpty ? text : tutorCaption + " " + text
        case let .action(.show(text)):
            expression = text
        case let .metrics(metrics):
            lastMetrics = metrics
        case let .error(message):
            errorMessage = message
        }
    }

    private func fail(_ error: Error) {
        errorMessage = error.localizedDescription
    }
}
