import Testing
@testable import TutorEngines

@MainActor
struct ProgressRelayTests {
    @Test func deliversEveryUpdateInOrderBeforeFinishReturns() async {
        var received: [Double] = []
        let relay = ProgressRelay { fraction, _ in received.append(fraction) }
        for step in 0...10 { relay.report(Double(step) / 10, "Voice") }
        await relay.finish()
        #expect(received == (0...10).map { Double($0) / 10 })
    }

    @Test func nothingIsDeliveredAfterFinish() async {
        var phase = "setup"
        let relay = ProgressRelay { _, _ in phase = "setup" }
        relay.report(1, "Voice")
        await relay.finish()
        // The caller's final state must survive any late reports from loader threads.
        phase = "ready"
        relay.report(1, "Voice")
        await Task.yield()
        #expect(phase == "ready")
    }
}
