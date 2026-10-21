import Foundation
import Testing
@testable import TutorEngines

@Test func spanishAndEnglishSamples() async throws {
    let models = try phononModelsDirectory()
    let speaker = try await PhononSpeaker.load(bundledModels: models)
    let voices: [(voice: String, language: ProbeLanguage)] = [
        (ModelCatalog.phononVoiceEnglish, .english),
        (ModelCatalog.phononVoiceSpanish, .spanish),
    ]
    #expect(speaker.voices.contains(ModelCatalog.phononVoiceEnglish))
    #expect(speaker.voices.contains(ModelCatalog.phononVoiceSpanish))

    let audioDirectory = repositoryRoot()
        .appendingPathComponent("spike-audio", isDirectory: true)
    try FileManager.default.createDirectory(at: audioDirectory, withIntermediateDirectories: true)

    for (voice, language) in voices {
        switch language {
        case .english:
            try await speaker.selectVoice(voice, language: .english)
        case .spanish:
            try await speaker.selectVoice(voice, language: .spanish)
        }
        let sentence = sentence(for: language)
        let startedAt = Date()
        var firstChunkSeconds: TimeInterval?
        var samples: [Float] = []

        for try await chunk in speaker.stream(sentence) {
            if firstChunkSeconds == nil {
                firstChunkSeconds = Date().timeIntervalSince(startedAt)
            }
            samples.append(contentsOf: chunk)
        }

        let firstChunk = try #require(firstChunkSeconds)
        #expect(firstChunk < 0.2)

        let elapsed = Date().timeIntervalSince(startedAt)
        let audioSeconds = Double(samples.count) / PhononSpeaker.sampleRate
        let realtimeFactor = elapsed > 0 ? audioSeconds / elapsed : 0
        let audioURL = audioDirectory.appendingPathComponent("phonon-\(voice).wav")
        try writeWAV(samples, to: audioURL)
        try recordProbeResult(
            voice: voice,
            language: language,
            timeToFirstChunk: firstChunk,
            realtimeFactor: realtimeFactor
        )
    }
}

private func phononModelsDirectory() throws -> URL {
    guard let path = ProcessInfo.processInfo.environment["PHONON_MODELS"], !path.isEmpty else {
        throw PhononProbeError.missingModelsPath
    }
    return URL(fileURLWithPath: path, isDirectory: true)
}

private func repositoryRoot() -> URL {
    URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
}

private func sentence(for language: ProbeLanguage) -> String {
    switch language {
    case .english:
        "Let's think about three quarters. If you cut a pizza into four equal slices and eat three, how many slices are left?"
    case .spanish:
        "Pensemos en tres cuartos. Si cortas una pizza en cuatro rebanadas iguales y te comes tres, ¿cuántas rebanadas quedan? Tres punto cinco es lo mismo que tres y medio."
    }
}

private func recordProbeResult(
    voice: String,
    language: ProbeLanguage,
    timeToFirstChunk: TimeInterval,
    realtimeFactor: Double
) throws {
    let resultsURL = repositoryRoot().appendingPathComponent("docs/spike/results.md")
    let fileManager = FileManager.default
    if !fileManager.fileExists(atPath: resultsURL.path) {
        try "# Spike results\n\n| Engine | Voice | Language | Time to first chunk | Real-time factor |\n| --- | --- | --- | ---: | ---: |\n"
            .write(to: resultsURL, atomically: true, encoding: .utf8)
    }

    let row = String(
        format: "| Phonon | %@ | %@ | %.3f s | %.2f |\n",
        voice,
        language.rawValue,
        timeToFirstChunk,
        realtimeFactor
    )
    let handle = try FileHandle(forWritingTo: resultsURL)
    defer { try? handle.close() }
    try handle.seekToEnd()
    try handle.write(contentsOf: Data(row.utf8))
}

private func writeWAV(_ samples: [Float], to url: URL) throws {
    let sampleRate = UInt32(PhononSpeaker.sampleRate)
    let dataSize = UInt32(samples.count * MemoryLayout<Float>.size)
    var data = Data()
    data.append(contentsOf: "RIFF".utf8)
    appendLittleEndian(36 + dataSize, to: &data)
    data.append(contentsOf: "WAVEfmt ".utf8)
    appendLittleEndian(UInt32(16), to: &data)
    appendLittleEndian(UInt16(3), to: &data)
    appendLittleEndian(UInt16(1), to: &data)
    appendLittleEndian(sampleRate, to: &data)
    appendLittleEndian(sampleRate * UInt32(MemoryLayout<Float>.size), to: &data)
    appendLittleEndian(UInt16(MemoryLayout<Float>.size), to: &data)
    appendLittleEndian(UInt16(32), to: &data)
    data.append(contentsOf: "data".utf8)
    appendLittleEndian(dataSize, to: &data)
    for sample in samples {
        appendLittleEndian(sample.bitPattern, to: &data)
    }
    try data.write(to: url, options: .atomic)
}

private func appendLittleEndian<Value: FixedWidthInteger>(_ value: Value, to data: inout Data) {
    var value = value.littleEndian
    withUnsafeBytes(of: &value) { data.append(contentsOf: $0) }
}

private enum PhononProbeError: LocalizedError {
    case missingModelsPath

    var errorDescription: String? {
        switch self {
        case .missingModelsPath:
            "Set PHONON_MODELS to the exported PhononModels directory before running this probe."
        }
    }
}

private enum ProbeLanguage: String {
    case english = "en"
    case spanish = "es"
}
