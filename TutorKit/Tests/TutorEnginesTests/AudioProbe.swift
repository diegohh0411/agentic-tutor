import Foundation
import Testing
import TutorAudio
import TutorCore
@testable import TutorEngines

/// Manual probe: needs a microphone, the built-in speakers (no headphones) and a quiet room.
@Suite(.enabled(if: ProcessInfo.processInfo.environment["TUTOR_INTEGRATION"] == "1"
    && ProcessInfo.processInfo.environment["TUTOR_AUDIO"] == "1"))
struct AudioProbe {
    @Test func echoLeakageOnBuiltInSpeakers() async throws {
        let path = try #require(ProcessInfo.processInfo.environment["PHONON_MODELS"])
        let speaker = try await PhononSpeaker.load(bundledModels: URL(fileURLWithPath: path, isDirectory: true))
        try await speaker.setLanguage(.english)
        var probe: [Float] = []
        for try await samples in speaker.stream("This is a short echo test. One, two, three.") {
            probe.append(contentsOf: samples)
        }
        #expect(!probe.isEmpty)

        let vad = try await SileroVAD.load()
        let io = try AudioIO()
        try io.start()
        defer { io.stop() }
        // Let voice processing settle before measuring.
        try await Task.sleep(for: .seconds(1))

        // Ambient baseline: the same duration of silence, to separate room noise from echo.
        let baseline = await EchoSelfTest.measure(
            io: io, vad: vad, probe: [Float](repeating: 0, count: probe.count))
        print("ECHO baseline speechChunks=\(baseline.speechChunks) totalChunks=\(baseline.totalChunks)")

        let result = await EchoSelfTest.measure(io: io, vad: vad, probe: probe)
        print("ECHO speechChunks=\(result.speechChunks) totalChunks=\(result.totalChunks) latency=\(io.outputLatency)")
        #expect(result.totalChunks > 0, "no microphone chunks arrived")
        #expect(result.speechChunks < EchoSelfTest.leakChunkCount, "echo leaks into the microphone")

        // duck() must take effect within 10 ms.
        let start = ProcessInfo.processInfo.systemUptime
        io.duck()
        let ducked = io.playerVolume
        let elapsed = ProcessInfo.processInfo.systemUptime - start
        print("DUCK volume=\(ducked) elapsed=\(elapsed * 1000) ms")
        #expect(ducked == AudioIO.duckedVolume)
        #expect(elapsed <= 0.010)
        io.unduck()
        #expect(io.playerVolume == 1)
    }
}
