import Testing
@testable import TutorAudio
import TutorCore

struct AudioIOTests {
    @Test func countsOnlyChunksAboveTheThreshold() {
        let vad = ScriptedVAD(probabilities: [0.1, 0.9, 0.5, 0.51, 0.99])
        let counter = EchoSelfTest.Counter(vad: vad)
        for _ in 0..<5 { counter.add([Float](repeating: 0, count: 512)) }
        #expect(counter.snapshot.totalChunks == 5)
        // 0.5 is not above the threshold; 0.9, 0.51 and 0.99 are.
        #expect(counter.snapshot.speechChunks == 3)
    }

    @Test func leaksFromThreeSpeechChunks() {
        #expect(!EchoSelfTest.isLeak(speechChunks: 2))
        #expect(EchoSelfTest.isLeak(speechChunks: 3))
    }
}

private final class ScriptedVAD: VoiceActivityDetecting {
    private var probabilities: [Float]
    init(probabilities: [Float]) { self.probabilities = probabilities }
    func speechProbability(_ chunk: [Float]) -> Float { probabilities.removeFirst() }
    func reset() {}
}
