import Foundation
import Testing
@testable import TutorEngines

struct InstallerTests {
    @Test func stepsMatchTheSpecifiedDownloads() {
        #expect(ModelInstaller.steps.map(\.title) == [
            "Voice detection", "Turn detection", "Speech recognition", "Tutor", "Voice",
        ])
        #expect(ModelInstaller.steps.map(\.approxBytes) == [
            2_000_000, 8_000_000, 612_000_000, 2_500_000_000, 75_000_000,
        ])
    }

    @Test func overallProgressIsWeightedByBytes() {
        let total = Double(ModelInstaller.steps.reduce(Int64(0)) { $0 + $1.approxBytes })
        #expect(ModelInstaller.overallFraction(stepIndex: 0, stepFraction: 0) == 0)
        // Halfway through the tutor download (index 3): the three smaller steps plus half of it.
        let expected = (2_000_000.0 + 8_000_000 + 612_000_000 + 1_250_000_000) / total
        #expect(abs(ModelInstaller.overallFraction(stepIndex: 3, stepFraction: 0.5) - expected) < 1e-9)
        #expect(abs(ModelInstaller.overallFraction(stepIndex: 4, stepFraction: 1) - 1) < 1e-9)
        // Out-of-range step fractions are clamped.
        #expect(ModelInstaller.overallFraction(stepIndex: 4, stepFraction: 2) <= 1)
        #expect(ModelInstaller.overallFraction(stepIndex: 2, stepFraction: -1)
            == ModelInstaller.overallFraction(stepIndex: 2, stepFraction: 0))
    }

    @Test func markerRoundTripsAndRejectsGarbage() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("installer-tests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let marker = directory.appendingPathComponent("nested/installed.json")

        #expect(!ModelInstaller.isInstalled(markerURL: marker))
        try ModelInstaller.writeMarker(to: marker)
        #expect(ModelInstaller.isInstalled(markerURL: marker))

        try Data("not json".utf8).write(to: marker)
        #expect(!ModelInstaller.isInstalled(markerURL: marker))

        // A marker written for a different tutor model no longer counts as installed.
        try Data(#"{"version":1,"tutorModelId":"someone/else"}"#.utf8).write(to: marker)
        #expect(!ModelInstaller.isInstalled(markerURL: marker))
    }
}
