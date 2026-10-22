import Foundation

/// Tracks queued playback so `isPlaying` ends even if the output device never reports completion
/// (for example when the audio hardware fails to start).
struct PlaybackTracker {
    /// How long past the expected end of the audio `isPlaying` stays true.
    static let grace: TimeInterval = 1.0

    private var pending = 0
    private var generation = 0
    private var expectedEnd: TimeInterval = 0

    /// Registers a buffer of `duration` seconds and returns the generation to pass to `completed`.
    mutating func enqueue(duration: TimeInterval, now: TimeInterval) -> Int {
        if pending > 0, now > expectedEnd + Self.grace {
            // Earlier buffers never reported completion; forget them.
            pending = 0
            generation += 1
        }
        pending += 1
        expectedEnd = max(expectedEnd, now) + duration
        return generation
    }

    /// Buffers dropped by a reset complete too; only the current generation counts.
    mutating func completed(generation completed: Int) {
        if completed == generation { pending = max(0, pending - 1) }
    }

    mutating func reset() {
        pending = 0
        generation += 1
        expectedEnd = 0
    }

    func isPlaying(now: TimeInterval) -> Bool {
        pending > 0 && now <= expectedEnd + Self.grace
    }
}
