import AVFoundation
import Foundation
import TutorCore

public enum AudioIOError: Error, Equatable {
    case voiceProcessingUnavailable
    case invalidInputFormat
}

/// Full-duplex audio: voice-processed microphone input at 16 kHz and tutor playback at 24 kHz.
///
/// Voice processing (echo cancellation) is enabled on the input node before the engine
/// starts. Microphone audio is converted to 16 kHz mono Float32 and delivered in
/// 512-sample chunks on the audio thread, so `onMicChunk` must return quickly.
public final class AudioIO: AudioOutput, @unchecked Sendable {
    public static let micSampleRate: Double = 16_000
    public static let playbackSampleRate: Double = 24_000
    public static let chunkSize = 512
    public static let duckedVolume: Float = 0.15

    /// Called with 512 samples at 16 kHz and `ProcessInfo.systemUptime` when they were captured.
    public var onMicChunk: ((_ chunk16k: [Float], _ time: TimeInterval) -> Void)? {
        get { state.withLock { $0.onMicChunk } }
        set { state.withLock { $0.onMicChunk = newValue } }
    }

    private struct State {
        var onMicChunk: ((_ chunk16k: [Float], _ time: TimeInterval) -> Void)?
        var accumulator = ChunkAccumulator(size: AudioIO.chunkSize)
        var converter: AVAudioConverter?
        var sourceMonoFormat: AVAudioFormat?
        var playback = PlaybackTracker()
        var isRunning = false
    }

    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private let playbackFormat: AVAudioFormat
    private let micFormat: AVAudioFormat
    private let state = Locked(State())
    private var configurationObserver: NSObjectProtocol?

    /// - Parameter voiceProcessing: `false` skips echo cancellation. The app uses that to keep
    ///   working (with a headphones recommendation) when voice processing is unavailable.
    public init(voiceProcessing: Bool = true) throws {
        guard let playbackFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32, sampleRate: Self.playbackSampleRate,
            channels: 1, interleaved: false),
            let micFormat = AVAudioFormat(
                commonFormat: .pcmFormatFloat32, sampleRate: Self.micSampleRate,
                channels: 1, interleaved: false)
        else { throw AudioIOError.invalidInputFormat }
        self.playbackFormat = playbackFormat
        self.micFormat = micFormat

        if voiceProcessing {
            do {
                try engine.inputNode.setVoiceProcessingEnabled(true)
            } catch {
                throw AudioIOError.voiceProcessingUnavailable
            }
        }

        // With voice processing on, the engine fails to initialize (-10875) unless the mixer
        // feeds the output node in exactly the format that node expects. Read that format
        // before the mixer is touched, because the default connection changes it.
        let outputFormat = engine.outputNode.inputFormat(forBus: 0)
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: playbackFormat)
        engine.connect(engine.mainMixerNode, to: engine.outputNode, format: outputFormat)
        configurationObserver = NotificationCenter.default.addObserver(
            forName: .AVAudioEngineConfigurationChange, object: engine, queue: nil
        ) { [weak self] _ in self?.restartAfterConfigurationChange() }
    }

    deinit {
        if let configurationObserver { NotificationCenter.default.removeObserver(configurationObserver) }
        stop()
    }

    public var isRunning: Bool { state.withLock { $0.isRunning } }

    public func start() throws {
        guard !isRunning else { return }
        try installTap()
        engine.prepare()
        try engine.start()
        player.play()
        state.withLock { $0.isRunning = true }
    }

    public func stop() {
        guard isRunning else { return }
        player.stop()
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        state.withLock {
            $0.isRunning = false
            $0.playback.reset()
            $0.accumulator = ChunkAccumulator(size: AudioIO.chunkSize)
        }
    }

    // MARK: - AudioOutput

    public func enqueue(_ samples24k: [Float]) {
        guard !samples24k.isEmpty,
              let buffer = AVAudioPCMBuffer(
                  pcmFormat: playbackFormat, frameCapacity: AVAudioFrameCount(samples24k.count)),
              let channel = buffer.floatChannelData?[0]
        else { return }
        samples24k.withUnsafeBufferPointer { channel.update(from: $0.baseAddress!, count: samples24k.count) }
        buffer.frameLength = AVAudioFrameCount(samples24k.count)

        let duration = Double(samples24k.count) / Self.playbackSampleRate
        let generation = state.withLock {
            $0.playback.enqueue(duration: duration, now: ProcessInfo.processInfo.systemUptime)
        }
        player.scheduleBuffer(buffer, completionCallbackType: .dataPlayedBack) { [weak self] _ in
            self?.state.withLock { $0.playback.completed(generation: generation) }
        }
    }

    public func duck() { player.volume = Self.duckedVolume }
    public func unduck() { player.volume = 1 }

    public func stopAll() {
        state.withLock { $0.playback.reset() }
        player.stop()
        player.volume = 1
        if isRunning { player.play() }
    }

    /// True while enqueued audio is still playing, bounded by the audio's expected duration plus
    /// a grace period so a player that never reports completion cannot stall the conversation.
    public var isPlaying: Bool {
        state.withLock { $0.playback.isPlaying(now: ProcessInfo.processInfo.systemUptime) }
    }

    public var outputLatency: TimeInterval { engine.outputNode.presentationLatency }

    /// The player's current volume, for verifying `duck()` and `unduck()`.
    public var playerVolume: Float { player.volume }

    // MARK: - Input

    private func installTap() throws {
        let input = engine.inputNode
        input.removeTap(onBus: 0)
        let hardwareFormat = input.outputFormat(forBus: 0)
        guard hardwareFormat.sampleRate > 0, hardwareFormat.channelCount > 0,
              let monoSource = AVAudioFormat(
                  commonFormat: .pcmFormatFloat32, sampleRate: hardwareFormat.sampleRate,
                  channels: 1, interleaved: false),
              let converter = AVAudioConverter(from: monoSource, to: micFormat)
        else { throw AudioIOError.invalidInputFormat }
        state.withLock {
            $0.converter = converter
            $0.sourceMonoFormat = monoSource
            $0.accumulator = ChunkAccumulator(size: AudioIO.chunkSize)
        }
        input.installTap(onBus: 0, bufferSize: 1024, format: hardwareFormat) { [weak self] buffer, _ in
            self?.handleMic(buffer, capturedAt: ProcessInfo.processInfo.systemUptime)
        }
    }

    private func handleMic(_ buffer: AVAudioPCMBuffer, capturedAt time: TimeInterval) {
        let (converter, source) = state.withLock { ($0.converter, $0.sourceMonoFormat) }
        guard let converter, let source,
              let channels = buffer.floatChannelData,
              let mono = AVAudioPCMBuffer(pcmFormat: source, frameCapacity: buffer.frameLength)
        else { return }
        // Voice processing delivers the cleaned signal on the first channel.
        mono.frameLength = buffer.frameLength
        mono.floatChannelData![0].update(from: channels[0], count: Int(buffer.frameLength))

        let ratio = micFormat.sampleRate / source.sampleRate
        let capacity = AVAudioFrameCount((Double(buffer.frameLength) * ratio).rounded(.up)) + 16
        guard let converted = AVAudioPCMBuffer(pcmFormat: micFormat, frameCapacity: capacity) else { return }
        var supplied = false
        var error: NSError?
        converter.convert(to: converted, error: &error) { _, status in
            if supplied {
                status.pointee = .noDataNow
                return nil
            }
            supplied = true
            status.pointee = .haveData
            return mono
        }
        guard error == nil, converted.frameLength > 0, let data = converted.floatChannelData else { return }
        let samples = Array(UnsafeBufferPointer(start: data[0], count: Int(converted.frameLength)))

        let (chunks, callback) = state.withLock { state in
            (state.accumulator.append(samples), state.onMicChunk)
        }
        guard let callback else { return }
        for chunk in chunks { callback(chunk, time) }
    }

    private func restartAfterConfigurationChange() {
        guard isRunning else { return }
        // The hardware format changed (device switch, sample rate change): rebuild the tap.
        engine.inputNode.removeTap(onBus: 0)
        do {
            try installTap()
            if !engine.isRunning { try engine.start() }
            player.play()
        } catch {
            state.withLock { $0.isRunning = false }
        }
    }
}

/// A minimal lock-protected value box, kept private to the audio layer.
final class Locked<Value>: @unchecked Sendable {
    private let lock = NSLock()
    private var value: Value

    init(_ value: Value) { self.value = value }

    func withLock<Result>(_ body: (inout Value) -> Result) -> Result {
        lock.lock()
        defer { lock.unlock() }
        return body(&value)
    }
}
