import Foundation
import Testing
@testable import TutorEngines

/// Runs with TUTOR_INTEGRATION=1, or alone with TUTOR_INSTALLER=1 (useful when launching the test
/// bundle directly, for example under `sandbox-exec` with the network denied).
@Suite(.enabled(if: ProcessInfo.processInfo.environment["TUTOR_INTEGRATION"] == "1"
    || ProcessInfo.processInfo.environment["TUTOR_INSTALLER"] == "1"))
struct InstallerProbe {
    @Test func secondLoadWorksOffline() async throws {
        guard let path = ProcessInfo.processInfo.environment["PHONON_MODELS"], !path.isEmpty else {
            throw InstallerProbeError.missingModelsPath
        }
        let models = URL(fileURLWithPath: path, isDirectory: true)
        // A scratch marker keeps the probe from touching a real installation.
        let marker = FileManager.default.temporaryDirectory
            .appendingPathComponent("installer-probe-\(UUID().uuidString)/installed.json")
        defer { try? FileManager.default.removeItem(at: marker.deletingLastPathComponent()) }

        #expect(!ModelInstaller.isInstalled(markerURL: marker))
        let first = Date()
        _ = try await ModelInstaller.loadAll(bundledPhonon: models, markerURL: marker) { _, _ in }
        let firstSeconds = Date().timeIntervalSince(first)
        #expect(ModelInstaller.isInstalled(markerURL: marker))

        let progress = ProgressLog()
        let second = Date()
        _ = try await ModelInstaller.loadAll(bundledPhonon: models, markerURL: marker) { fraction, title in
            progress.record(fraction, title)
        }
        let secondSeconds = Date().timeIntervalSince(second)
        print("INSTALLER first load \(firstSeconds) s, second (offline) load \(secondSeconds) s")

        #expect(secondSeconds < 30)
        #expect(ModelInstaller.isInstalled(markerURL: marker))
        #expect(progress.isMonotonic)
        #expect(progress.last == 1)
    }
}

extension InstallerProbe {
    /// Loads with a pre-written marker, so every engine takes its offline path. Run it with the
    /// network blocked (for example under `sandbox-exec -p '(version 1)(allow default)(deny network*)'`)
    /// to prove an installed app never contacts the network.
    @Test func loadsFromInstalledMarkerOnly() async throws {
        guard let path = ProcessInfo.processInfo.environment["PHONON_MODELS"], !path.isEmpty else {
            throw InstallerProbeError.missingModelsPath
        }
        let marker = FileManager.default.temporaryDirectory
            .appendingPathComponent("installer-probe-\(UUID().uuidString)/installed.json")
        defer { try? FileManager.default.removeItem(at: marker.deletingLastPathComponent()) }
        try ModelInstaller.writeMarker(to: marker)

        let start = Date()
        _ = try await ModelInstaller.loadAll(
            bundledPhonon: URL(fileURLWithPath: path, isDirectory: true), markerURL: marker
        ) { _, _ in }
        let seconds = Date().timeIntervalSince(start)
        print("INSTALLER marker-only load \(seconds) s")
        // A fall back to downloading removes the marker, so it must survive an offline load.
        #expect(ModelInstaller.isInstalled(markerURL: marker))
        #expect(seconds < 30)
    }
}

private final class ProgressLog: @unchecked Sendable {
    private let lock = NSLock()
    private var values: [Double] = []

    func record(_ fraction: Double, _ title: String) {
        lock.lock(); defer { lock.unlock() }
        values.append(fraction)
    }

    var last: Double? { lock.lock(); defer { lock.unlock() }; return values.last }

    var isMonotonic: Bool {
        lock.lock(); defer { lock.unlock() }
        return zip(values, values.dropFirst()).allSatisfy { $0 <= $1 + 1e-9 }
    }
}

private enum InstallerProbeError: LocalizedError {
    case missingModelsPath

    var errorDescription: String? { "Set PHONON_MODELS to the exported PhononModels directory." }
}
