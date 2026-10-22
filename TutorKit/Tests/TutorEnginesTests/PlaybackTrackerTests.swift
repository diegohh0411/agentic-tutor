import Testing
@testable import TutorAudio

struct PlaybackTrackerTests {
    @Test func playsUntilEveryBufferCompletes() {
        var tracker = PlaybackTracker()
        let first = tracker.enqueue(duration: 1, now: 100)
        let second = tracker.enqueue(duration: 1, now: 100.1)
        #expect(tracker.isPlaying(now: 100.5))
        tracker.completed(generation: first)
        #expect(tracker.isPlaying(now: 101.5))
        tracker.completed(generation: second)
        #expect(!tracker.isPlaying(now: 101.5))
    }

    @Test func stopsAfterExpectedDurationPlusGraceWhenNoCompletionArrives() {
        var tracker = PlaybackTracker()
        _ = tracker.enqueue(duration: 2, now: 100)
        #expect(tracker.isPlaying(now: 102.9))
        #expect(!tracker.isPlaying(now: 103.1))
    }

    @Test func resetIgnoresLateCompletionsOfDroppedBuffers() {
        var tracker = PlaybackTracker()
        let old = tracker.enqueue(duration: 5, now: 100)
        tracker.reset()
        #expect(!tracker.isPlaying(now: 100.1))
        let fresh = tracker.enqueue(duration: 5, now: 100.2)
        tracker.completed(generation: old)
        #expect(tracker.isPlaying(now: 100.3))
        tracker.completed(generation: fresh)
        #expect(!tracker.isPlaying(now: 100.3))
    }

    @Test func staleUncompletedBuffersAreForgottenOnNextEnqueue() {
        var tracker = PlaybackTracker()
        let stale = tracker.enqueue(duration: 1, now: 100)
        let fresh = tracker.enqueue(duration: 1, now: 110)
        tracker.completed(generation: stale)
        #expect(tracker.isPlaying(now: 110.5))
        tracker.completed(generation: fresh)
        #expect(!tracker.isPlaying(now: 110.5))
    }
}
