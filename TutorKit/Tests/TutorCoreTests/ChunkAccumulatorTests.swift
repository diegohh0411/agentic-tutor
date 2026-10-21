import Testing
@testable import TutorCore

@Test func carriesPartialSamplesIntoTheNextChunk() {
    var accumulator = ChunkAccumulator()
    #expect(accumulator.append(Array(repeating: 1, count: 300)).isEmpty)
    let chunks = accumulator.append(Array(repeating: 2, count: 300))
    #expect(chunks.count == 1)
    #expect(chunks[0].count == 512)
    #expect(chunks[0].prefix(300).allSatisfy { $0 == 1 })
    let next = accumulator.append(Array(repeating: 3, count: 424))
    #expect(next.count == 1)
    #expect(next[0].prefix(88).allSatisfy { $0 == 2 })
}
