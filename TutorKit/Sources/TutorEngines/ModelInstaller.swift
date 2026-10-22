import Foundation
import os
import TutorCore

/// The engines the app needs for a conversation, loaded and warmed.
public struct LoadedEngines: @unchecked Sendable {
    public let vad: SileroVAD
    public let judge: SmartTurnJudge
    public let asr: NemotronTranscriber
    public let tutor: QwenTutor
    public let tts: PhononSpeaker
}

public struct InstallStep: Sendable {
    public let title: String
    public let approxBytes: Int64

    public init(title: String, approxBytes: Int64) {
        self.title = title
        self.approxBytes = approxBytes
    }
}

/// Downloads the models on first run and loads them without the network afterwards.
public enum ModelInstaller {
    public static var steps: [InstallStep] {
        [
            InstallStep(title: "Voice detection", approxBytes: 2_000_000),
            InstallStep(title: "Turn detection", approxBytes: 8_000_000),
            InstallStep(title: "Speech recognition", approxBytes: 612_000_000),
            InstallStep(title: "Tutor", approxBytes: 2_500_000_000),
            InstallStep(title: "Voice", approxBytes: 75_000_000),
        ]
    }

    /// Whether a previous `loadAll` finished, recorded by a marker in Application Support.
    public static var isInstalled: Bool { isInstalled(markerURL: defaultMarkerURL) }

    public static var defaultMarkerURL: URL {
        URL.applicationSupportDirectory
            .appendingPathComponent("AgenticTutor", isDirectory: true)
            .appendingPathComponent("installed.json")
    }

    /// Loads every engine, reporting progress weighted by `approxBytes`.
    ///
    /// The marker is written only after all loads succeed. While it exists, models load from
    /// their local caches and the network is never contacted. If a cache turned out to be
    /// missing (for example, cleared by the system), the marker is removed and the models are
    /// downloaded again.
    public static func loadAll(
        bundledPhonon: URL,
        markerURL: URL = defaultMarkerURL,
        progress: @escaping @Sendable (_ fraction: Double, _ title: String) -> Void
    ) async throws -> LoadedEngines {
        var offline = isInstalled(markerURL: markerURL)
        while true {
            do {
                let engines = try await load(bundledPhonon: bundledPhonon, offline: offline, progress: progress)
                try writeMarker(to: markerURL)
                progress(1, steps.last?.title ?? "")
                return engines
            } catch {
                // A stuck step is reported as is; only a missing cache falls back to downloading.
                if case InstallerError.stepTimedOut = error { throw error }
                guard offline else { throw error }
                try? FileManager.default.removeItem(at: markerURL)
                offline = false
            }
        }
    }

    // MARK: - Weighting

    /// Overall fraction when step `index` is `stepFraction` done and earlier steps are complete.
    static func overallFraction(
        stepIndex index: Int,
        stepFraction: Double,
        steps: [InstallStep] = ModelInstaller.steps
    ) -> Double {
        let total = steps.reduce(Int64(0)) { $0 + $1.approxBytes }
        guard total > 0, steps.indices.contains(index) else { return 0 }
        let done = steps[..<index].reduce(Int64(0)) { $0 + $1.approxBytes }
        let within = Double(steps[index].approxBytes) * min(max(stepFraction, 0), 1)
        return (Double(done) + within) / Double(total)
    }

    // MARK: - Marker

    private struct Marker: Codable {
        var version: Int
        var tutorModelId: String
    }

    private static let markerVersion = 1

    private static var currentTutorModelId: String {
        ModelCatalog.tutorModelId(physicalMemory: ProcessInfo.processInfo.physicalMemory)
    }

    static func isInstalled(markerURL: URL) -> Bool {
        guard let data = try? Data(contentsOf: markerURL),
              let marker = try? JSONDecoder().decode(Marker.self, from: data)
        else { return false }
        return marker.version == markerVersion && marker.tutorModelId == currentTutorModelId
    }

    static func writeMarker(to url: URL) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(Marker(version: markerVersion, tutorModelId: currentTutorModelId))
        try data.write(to: url, options: .atomic)
    }

    // MARK: - Loading

    private static let log = Logger(subsystem: "AgenticTutor", category: "installer")

    /// How long an already-installed model may take to load before the step is reported as stuck.
    /// Downloads have no limit because their duration depends on the connection.
    static let installedStepTimeout: TimeInterval = 120

    private static func load(
        bundledPhonon: URL,
        offline: Bool,
        progress: @escaping @Sendable (Double, String) -> Void
    ) async throws -> LoadedEngines {
        let steps = steps
        let timeout: TimeInterval? = offline ? installedStepTimeout : nil
        @Sendable func report(_ index: Int) -> @Sendable (Double) -> Void {
            { fraction in
                progress(overallFraction(stepIndex: index, stepFraction: fraction, steps: steps), steps[index].title)
            }
        }
        func step<T>(_ index: Int, _ work: @escaping @Sendable () async throws -> T) async throws -> T {
            let title = steps[index].title
            report(index)(0)
            log.info("load start: \(title, privacy: .public) (offline: \(offline))")
            let began = Date()
            do {
                let result = try await withStepTimeout(title: title, seconds: timeout, work)
                log.info("load done: \(title, privacy: .public) in \(Date().timeIntervalSince(began), format: .fixed(precision: 2)) s")
                return result
            } catch {
                log.error("load failed: \(title, privacy: .public) after \(Date().timeIntervalSince(began), format: .fixed(precision: 2)) s: \(error.localizedDescription, privacy: .public)")
                throw error
            }
        }

        let modelId = currentTutorModelId
        let vad = try await step(0) { Unchecked(try await SileroVAD.load(offline: offline, progress: report(0))) }.value
        let judge = try await step(1) { Unchecked(try await SmartTurnJudge.load(offline: offline, progress: report(1))) }.value
        let asr = try await step(2) { Unchecked(try await NemotronTranscriber.load(offline: offline, progress: report(2))) }.value
        let tutor = try await step(3) {
            Unchecked(try await QwenTutor.load(modelId: modelId, localFilesOnly: offline, progress: report(3)))
        }.value
        let tts = try await step(4) { Unchecked(try await PhononSpeaker.load(bundledModels: bundledPhonon)) }.value
        return LoadedEngines(vad: vad, judge: judge, asr: asr, tutor: tutor, tts: tts)
    }
}

/// Carries a non-Sendable engine out of the task that loaded it.
struct Unchecked<Value>: @unchecked Sendable {
    let value: Value
    init(_ value: Value) { self.value = value }
}

enum InstallerError: LocalizedError {
    case stepTimedOut(String)

    var errorDescription: String? {
        switch self {
        case .stepTimedOut(let title): "\(title) did not finish"
        }
    }
}

/// Runs `work`, failing with `InstallerError.stepTimedOut` if it has not finished after `seconds`.
///
/// The work runs in its own task. If it is stuck in non-cancellable code, the timeout still
/// returns to the caller (the stuck task is abandoned), which a task group would not allow.
func withStepTimeout<T: Sendable>(
    title: String,
    seconds: TimeInterval?,
    _ work: @escaping @Sendable () async throws -> T
) async throws -> T {
    guard let seconds else { return try await work() }
    return try await withCheckedThrowingContinuation { continuation in
        let once = OnceFlag()
        let worker = Task {
            do {
                let value = try await work()
                if once.claim() { continuation.resume(returning: value) }
            } catch {
                if once.claim() { continuation.resume(throwing: error) }
            }
        }
        Task {
            try? await Task.sleep(for: .seconds(seconds))
            if once.claim() {
                worker.cancel()
                continuation.resume(throwing: InstallerError.stepTimedOut(title))
            }
        }
    }
}

private final class OnceFlag: @unchecked Sendable {
    private let lock = NSLock()
    private var claimed = false

    func claim() -> Bool {
        lock.lock(); defer { lock.unlock() }
        if claimed { return false }
        claimed = true
        return true
    }
}
