import Foundation
import TutorCore

/// Plays a probe phrase through the speakers and checks whether the microphone hears it.
public enum EchoSelfTest {
    public static let speechThreshold: Float = 0.5
    public static let leakChunkCount = 3

    /// Plays `probe` (24 kHz) and counts VAD chunks above 0.5 while it plays; leaks if count >= 3.
    ///
    /// Returns `true` when the voice-processed microphone still picks up the speaker output.
    public static func run(io: AudioIO, vad: VoiceActivityDetecting, probe: [Float]) async -> Bool {
        let result = await measure(io: io, vad: vad, probe: probe)
        return isLeak(speechChunks: result.speechChunks)
    }

    /// Like `run`, returning the number of microphone chunks the VAD marked as speech.
    public static func measure(
        io: AudioIO,
        vad: VoiceActivityDetecting,
        probe: [Float]
    ) async -> (speechChunks: Int, totalChunks: Int) {
        let counter = Counter(vad: vad)
        let previousHandler = io.onMicChunk
        let wasRunning = io.isRunning
        if !wasRunning {
            do { try io.start() } catch { return (0, 0) }
        }
        vad.reset()
        io.onMicChunk = { chunk, _ in counter.add(chunk) }
        io.enqueue(probe)

        // Count while the phrase plays; the timeout covers a player that never reports completion.
        let duration = Double(probe.count) / AudioIO.playbackSampleRate
        let deadline = Date().addingTimeInterval(duration + 2)
        repeat {
            try? await Task.sleep(for: .milliseconds(20))
        } while io.isPlaying && Date() < deadline && !Task.isCancelled

        io.onMicChunk = previousHandler
        io.stopAll()
        if !wasRunning { io.stop() }
        vad.reset()
        return counter.snapshot
    }

    static func isLeak(speechChunks: Int) -> Bool { speechChunks >= leakChunkCount }

    final class Counter: @unchecked Sendable {
        private let lock = NSLock()
        private let vad: VoiceActivityDetecting
        private var speech = 0
        private var total = 0

        init(vad: VoiceActivityDetecting) { self.vad = vad }

        func add(_ chunk: [Float]) {
            lock.lock(); defer { lock.unlock() }
            total += 1
            if vad.speechProbability(chunk) > EchoSelfTest.speechThreshold { speech += 1 }
        }

        var snapshot: (speechChunks: Int, totalChunks: Int) {
            lock.lock(); defer { lock.unlock() }
            return (speech, total)
        }
    }
}
