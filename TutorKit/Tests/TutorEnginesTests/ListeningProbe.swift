import AVFoundation
import Foundation
import Testing
@testable import TutorEngines

@Suite(.enabled(if: ProcessInfo.processInfo.environment["TUTOR_INTEGRATION"] == "1"))
struct ListeningProbe {
    @Test func vadSeparatesSpeechFromSilence() async throws {
        let vad = try await SileroVAD.load()
        let silence = [Float](repeating: 0, count: 16_000)
        let silenceMaximum = listeningChunks(from: silence)
            .map(vad.speechProbability)
            .max() ?? 0
        #expect(silenceMaximum < 0.2)

        vad.reset()
        let speech = try listeningLoad16kMonoAudio(named: "en-01")
        let speechChunks = listeningChunks(from: speech)
        let speechCount = speechChunks.map(vad.speechProbability).filter { $0 > 0.5 }.count
        #expect(speechCount >= 10)
    }

    @Test func smartTurnSeparatesCompleteFromCutOff() async throws {
        let judge = try await SmartTurnJudge.load()
        let audio = try listeningLoad16kMonoAudio(named: "en-01")
        let startedAt = ContinuousClock.now
        let completeProbability = try judge.completionProbability(turnAudio: audio)
        let elapsed = startedAt.duration(to: .now)
        #expect(completeProbability > 0.5)
        var results = [SmartTurnProbeResult(
            recording: "en-01",
            completeProbability: completeProbability,
            prePauseProbability: nil,
            inferenceMilliseconds: Double(elapsed.components.attoseconds) / 1e15
                + Double(elapsed.components.seconds) * 1_000
        )]

        for prefix in ["en", "es"] {
            for line in 8...10 {
                let recording = String(format: "%@-%02d", prefix, line)
                let clip = try listeningLoad16kMonoAudio(named: recording)
                let silenceStart = try #require(listeningFirstSilenceStart(in: clip))
                let prePauseCount = min(clip.count, silenceStart + Int(0.3 * 16_000))
                let prePause = Array(clip.prefix(prePauseCount))
                let fullProbability = try judge.completionProbability(turnAudio: clip)
                let prePauseProbability = try judge.completionProbability(turnAudio: prePause)
                results.append(SmartTurnProbeResult(
                    recording: recording,
                    completeProbability: fullProbability,
                    prePauseProbability: prePauseProbability,
                    inferenceMilliseconds: nil
                ))
            }
        }

        let naturalPauseResults = results.dropFirst()
        #expect(naturalPauseResults.filter {
            $0.completeProbability >= 0.5 && ($0.prePauseProbability ?? 1) < 0.5
        }.count >= 4)

        try listeningAppendSmartTurnResults(results)
    }
}

private struct SmartTurnProbeResult {
    let recording: String
    let completeProbability: Float
    let prePauseProbability: Float?
    let inferenceMilliseconds: Double?
}

private func listeningChunks(from samples: [Float]) -> [[Float]] {
    stride(from: 0, to: samples.count, by: SileroVAD.chunkSize).map { offset in
        var chunk = Array(samples[offset..<min(offset + SileroVAD.chunkSize, samples.count)])
        chunk.append(contentsOf: repeatElement(0, count: SileroVAD.chunkSize - chunk.count))
        return chunk
    }
}

private func listeningLoad16kMonoAudio(named basename: String) throws -> [Float] {
    let directory = listeningRepositoryRoot().appendingPathComponent("spike-audio", isDirectory: true)
    let urls = try FileManager.default.contentsOfDirectory(
        at: directory,
        includingPropertiesForKeys: nil,
        options: [.skipsHiddenFiles]
    )
    guard let url = urls.first(where: {
        $0.deletingPathExtension().lastPathComponent == basename && $0.pathExtension.lowercased() == "m4a"
    }) else {
        throw ListeningProbeError.missingRecording(basename)
    }
    return try listeningDecode16kMono(url)
}

private func listeningDecode16kMono(_ url: URL) throws -> [Float] {
    let file = try AVAudioFile(forReading: url)
    guard let outputFormat = AVAudioFormat(
        commonFormat: .pcmFormatFloat32,
        sampleRate: 16_000,
        channels: 1,
        interleaved: false
    ), let converter = AVAudioConverter(from: file.processingFormat, to: outputFormat) else {
        throw ListeningProbeError.audioConversion(url)
    }

    let inputCapacity = AVAudioFrameCount(file.length)
    guard let input = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: inputCapacity) else {
        throw ListeningProbeError.audioConversion(url)
    }
    try file.read(into: input)
    let outputCapacity = AVAudioFrameCount(
        (Double(input.frameLength) * outputFormat.sampleRate / file.processingFormat.sampleRate).rounded(.up)
    ) + 1
    guard let output = AVAudioPCMBuffer(pcmFormat: outputFormat, frameCapacity: outputCapacity) else {
        throw ListeningProbeError.audioConversion(url)
    }

    var suppliedInput = false
    var conversionError: NSError?
    let status = converter.convert(to: output, error: &conversionError) { _, outStatus in
        if suppliedInput {
            outStatus.pointee = .noDataNow
            return nil
        }
        suppliedInput = true
        outStatus.pointee = .haveData
        return input
    }
    if status == .error {
        throw conversionError ?? ListeningProbeError.audioConversion(url)
    }
    guard let channel = output.floatChannelData?[0] else {
        throw ListeningProbeError.audioConversion(url)
    }
    return Array(UnsafeBufferPointer(start: channel, count: Int(output.frameLength)))
}

private func listeningFirstSilenceStart(in samples: [Float]) -> Int? {
    let windowSize = 160 // 10 ms at the probe's 16 kHz sample rate.
    let requiredWindows = 100 // Detect a continuous silent run of at least 1.0 s.
    let rmsThreshold: Float = 0.005
    var runStart: Int?
    var runLength = 0

    for start in stride(from: 0, to: samples.count - windowSize + 1, by: windowSize) {
        let window = samples[start..<(start + windowSize)]
        let meanSquare = window.reduce(Float.zero) { $0 + $1 * $1 } / Float(windowSize)
        if meanSquare.squareRoot() < rmsThreshold {
            if runStart == nil { runStart = start }
            runLength += 1
            if runLength >= requiredWindows { return runStart }
        } else {
            runStart = nil
            runLength = 0
        }
    }
    return nil
}

private func listeningAppendSmartTurnResults(_ results: [SmartTurnProbeResult]) throws {
    let resultsURL = listeningRepositoryRoot().appendingPathComponent("docs/spike/results.md")
    let table = """

    ## Smart Turn probe

    | Recording | Complete probability | Pre-pause probability | Inference |
    | --- | ---: | ---: | ---: |
    """
    for result in results {
        let prePause = result.prePauseProbability.map { String(format: "%.3f", $0) } ?? "—"
        let inference = result.inferenceMilliseconds.map { String(format: "%.1f ms", $0) } ?? "—"
        table += "| \(result.recording) | \(String(format: "%.3f", result.completeProbability)) | \(prePause) | \(inference) |\\n"
    }
    try listeningAppend(table + "\n", to: resultsURL)
}

private func listeningAppend(_ text: String, to url: URL) throws {
    let fileManager = FileManager.default
    if !fileManager.fileExists(atPath: url.path) {
        try "# Spike results\n".write(to: url, atomically: true, encoding: .utf8)
    }
    let handle = try FileHandle(forWritingTo: url)
    defer { try? handle.close() }
    try handle.seekToEnd()
    try handle.write(contentsOf: Data(text.utf8))
}

private func listeningRepositoryRoot() -> URL {
    URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
}

private enum ListeningProbeError: LocalizedError {
    case missingRecording(String)
    case audioConversion(URL)

    var errorDescription: String? {
        switch self {
        case let .missingRecording(name):
            "Missing spike-audio/\(name).m4a recording."
        case let .audioConversion(url):
            "Could not decode \(url.lastPathComponent) as 16 kHz mono Float32 audio."
        }
    }
}
