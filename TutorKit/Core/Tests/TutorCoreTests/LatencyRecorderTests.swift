import Foundation
import Testing
@testable import TutorCore

private let latencyTolerance: TimeInterval = 1e-9

@Test func computesReplyLatency() {
    var recorder = LatencyRecorder()
    recorder.mark(.turnEnded(silenceAllowance: 0.5), at: 10.0)
    recorder.mark(.asrFinal, at: 10.05)
    recorder.mark(.llmFirstToken, at: 10.35)
    recorder.mark(.ttsFirstChunk, at: 10.40)
    recorder.mark(.firstEnqueue(outputLatency: 0.02), at: 10.41)

    let metrics = recorder.close(footprint: 123)

    #expect(abs((metrics.replyLatency ?? .infinity) - 0.43) <= latencyTolerance)
    #expect(abs((metrics.asrFinalize ?? .infinity) - 0.05) <= latencyTolerance)
    #expect(abs((metrics.llmFirstToken ?? .infinity) - 0.30) <= latencyTolerance)
    #expect(abs((metrics.ttsFirstAudio ?? .infinity) - 0.05) <= latencyTolerance)
    #expect(metrics.silenceAllowance == 0.5)
    #expect(metrics.footprintBytes == 123)
}

@Test func bargeInDuck() {
    var recorder = LatencyRecorder()
    recorder.mark(.speechOnset, at: 5.0)
    recorder.mark(.duck, at: 5.07)

    let metrics = recorder.close(footprint: 0)

    #expect(abs((metrics.bargeInDuck ?? .infinity) - 0.07) <= latencyTolerance)
}

@Test func closeResetsMarksAndMissingPairsAreNil() {
    var recorder = LatencyRecorder()
    recorder.mark(.asrFinal, at: 1)
    recorder.mark(.firstEnqueue(outputLatency: 0.02), at: 2)
    _ = recorder.close(footprint: 10)

    let metrics = recorder.close(footprint: 20)

    #expect(metrics.silenceAllowance == nil)
    #expect(metrics.asrFinalize == nil)
    #expect(metrics.llmFirstToken == nil)
    #expect(metrics.ttsFirstAudio == nil)
    #expect(metrics.replyLatency == nil)
    #expect(metrics.bargeInDuck == nil)
    #expect(metrics.footprintBytes == 20)
}

@Test func footprintIsPositive() {
    #expect(currentFootprintBytes() > 0)
}
