import Foundation
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

    private static func load(
        bundledPhonon: URL,
        offline: Bool,
        progress: @escaping @Sendable (Double, String) -> Void
    ) async throws -> LoadedEngines {
        let steps = steps
        func report(_ index: Int) -> @Sendable (Double) -> Void {
            { fraction in
                progress(overallFraction(stepIndex: index, stepFraction: fraction, steps: steps), steps[index].title)
            }
        }
        func started(_ index: Int) { report(index)(0) }

        started(0)
        let vad = try await SileroVAD.load(offline: offline, progress: report(0))
        started(1)
        let judge = try await SmartTurnJudge.load(offline: offline, progress: report(1))
        started(2)
        let asr = try await NemotronTranscriber.load(offline: offline, progress: report(2))
        started(3)
        let tutor = try await QwenTutor.load(
            modelId: currentTutorModelId, localFilesOnly: offline, progress: report(3))
        started(4)
        let tts = try await PhononSpeaker.load(bundledModels: bundledPhonon)
        return LoadedEngines(vad: vad, judge: judge, asr: asr, tutor: tutor, tts: tts)
    }
}
