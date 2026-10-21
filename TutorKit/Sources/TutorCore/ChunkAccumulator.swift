public struct ChunkAccumulator {
    private let size: Int
    private var remainder: [Float] = []

    public init(size: Int = 512) {
        self.size = max(1, size)
    }

    public mutating func append(_ samples: [Float]) -> [[Float]] {
        remainder.append(contentsOf: samples)
        var chunks: [[Float]] = []
        while remainder.count >= size {
            chunks.append(Array(remainder.prefix(size)))
            remainder.removeFirst(size)
        }
        return chunks
    }
}
