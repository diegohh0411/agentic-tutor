import Foundation

/// Delivers install progress from background loaders to a main-actor handler, in order.
///
/// `finish()` waits until every reported update has been delivered, so the caller can set its
/// final state afterwards without a late progress update overwriting it.
@MainActor
public final class ProgressRelay {
    public typealias Update = (fraction: Double, title: String)

    private let continuation: AsyncStream<Update>.Continuation
    private var consumer: Task<Void, Never>?

    public init(handler: @escaping @MainActor (_ fraction: Double, _ title: String) -> Void) {
        let (stream, continuation) = AsyncStream.makeStream(of: Update.self, bufferingPolicy: .unbounded)
        self.continuation = continuation
        consumer = Task { @MainActor in
            for await update in stream { handler(update.fraction, update.title) }
        }
    }

    /// Safe to call from any thread.
    public nonisolated func report(_ fraction: Double, _ title: String) {
        continuation.yield((fraction, title))
    }

    /// Delivers everything reported so far, then stops. No handler call happens after it returns.
    public func finish() async {
        continuation.finish()
        await consumer?.value
        consumer = nil
    }
}
