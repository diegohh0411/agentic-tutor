import Foundation

/// Timestamps frames by sample position, independent of capture callback scheduling.
/// Recreate this clock whenever capture restarts or the input format changes.
struct MicChunkClock {
    private var origin: TimeInterval?
    private var emittedChunks = 0

    mutating func next(capturedAt time: TimeInterval) -> TimeInterval {
        if origin == nil { origin = time }
        defer { emittedChunks += 1 }
        return origin! + Double(emittedChunks * AudioIO.chunkSize) / AudioIO.micSampleRate
    }
}
