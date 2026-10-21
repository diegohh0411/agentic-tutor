import AVFoundation
import Foundation
import Testing
import TutorCore
@testable import TutorEngines

@Suite(.enabled(if: ProcessInfo.processInfo.environment["TUTOR_INTEGRATION"] == "1"))
struct NemotronProbe {
    @Test func transcribesOwnerRecordings() async throws {
        let transcriber = try await NemotronTranscriber.load()
        let scripts = try asrProbeScripts()
        var results: [ASRProbeResult] = []

        for language in TutorLanguage.allCases {
            let lines = try #require(scripts[language])
            for line in lines {
                let audio = try asrProbeLoad16kMonoAudio(named: line.recordingName)
                try transcriber.begin(language: language)
                for chunk in asrProbeChunks(from: audio) {
                    _ = try transcriber.push(chunk)
                }
                let transcript = try transcriber.finish()
                results.append(ASRProbeResult(
                    language: language,
                    recording: line.recordingName,
                    reference: line.text,
                    transcript: transcript,
                    wer: asrProbeWER(reference: line.text, hypothesis: transcript)
                ))
            }
        }

        try asrProbeAppendResults(results)

        for language in TutorLanguage.allCases {
            let languageResults = results.filter { $0.language == language }
            let meanWER = languageResults.map(\.wer).reduce(0, +) / Double(languageResults.count)
            #expect(meanWER < 0.15)

            for term in Set(NemotronTranscriber.mathVocabulary[language] ?? []) {
                let referencesContainingTerm = languageResults.filter {
                    asrProbeContains(asrProbeWords(term), in: asrProbeWords($0.reference))
                }
                guard !referencesContainingTerm.isEmpty else { continue }
                let recognized = referencesContainingTerm.filter {
                    asrProbeContains(asrProbeWords(term), in: asrProbeWords($0.transcript))
                }.count
                let recall = Double(recognized) / Double(referencesContainingTerm.count)
                #expect(recall >= 0.8)
            }
        }
    }
}

private struct ASRProbeScriptLine {
    let recordingName: String
    let text: String
}

private struct ASRProbeResult {
    let language: TutorLanguage
    let recording: String
    let reference: String
    let transcript: String
    let wer: Double
}

private func asrProbeScripts() throws -> [TutorLanguage: [ASRProbeScriptLine]] {
    let scriptURL = asrProbeRepositoryRoot().appendingPathComponent("docs/spike/asr-script.md")
    let script = try String(contentsOf: scriptURL, encoding: .utf8)
    var language: TutorLanguage?
    var lines: [TutorLanguage: [ASRProbeScriptLine]] = [:]

    for rawLine in script.components(separatedBy: .newlines) {
        switch rawLine {
        case "## English":
            language = .english
            continue
        case "## Mexican Spanish":
            language = .spanish
            continue
        default:
            break
        }
        guard let language,
              let separator = rawLine.firstIndex(of: "."),
              let number = Int(rawLine[..<separator].trimmingCharacters(in: .whitespaces)),
              (1...10).contains(number)
        else { continue }

        let text = rawLine[rawLine.index(after: separator)...]
            .replacingOccurrences(of: #"[~1.5 s thinking pause]"#, with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let prefix = language == .english ? "en" : "es"
        lines[language, default: []].append(ASRProbeScriptLine(
            recordingName: String(format: "%@-%02d", prefix, number),
            text: text
        ))
    }
    return lines
}

private func asrProbeChunks(from samples: [Float]) -> [[Float]] {
    stride(from: 0, to: samples.count, by: 512).map { offset in
        Array(samples[offset..<min(offset + 512, samples.count)])
    }
}

private func asrProbeLoad16kMonoAudio(named basename: String) throws -> [Float] {
    let directory = asrProbeRepositoryRoot().appendingPathComponent("spike-audio", isDirectory: true)
    let urls = try FileManager.default.contentsOfDirectory(
        at: directory,
        includingPropertiesForKeys: nil,
        options: [.skipsHiddenFiles]
    )
    guard let url = urls.first(where: {
        $0.deletingPathExtension().lastPathComponent == basename && $0.pathExtension.lowercased() == "m4a"
    }) else {
        throw ASRProbeError.missingRecording(basename)
    }
    return try asrProbeDecode16kMono(url)
}

private func asrProbeDecode16kMono(_ url: URL) throws -> [Float] {
    let file = try AVAudioFile(forReading: url)
    guard let outputFormat = AVAudioFormat(
        commonFormat: .pcmFormatFloat32,
        sampleRate: 16_000,
        channels: 1,
        interleaved: false
    ), let converter = AVAudioConverter(from: file.processingFormat, to: outputFormat) else {
        throw ASRProbeError.audioConversion(url)
    }

    let inputCapacity = AVAudioFrameCount(file.length)
    guard let input = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: inputCapacity) else {
        throw ASRProbeError.audioConversion(url)
    }
    try file.read(into: input)
    let outputCapacity = AVAudioFrameCount(
        (Double(input.frameLength) * outputFormat.sampleRate / file.processingFormat.sampleRate).rounded(.up)
    ) + 1
    guard let output = AVAudioPCMBuffer(pcmFormat: outputFormat, frameCapacity: outputCapacity) else {
        throw ASRProbeError.audioConversion(url)
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
        throw conversionError ?? ASRProbeError.audioConversion(url)
    }
    guard let channel = output.floatChannelData?[0] else {
        throw ASRProbeError.audioConversion(url)
    }
    return Array(UnsafeBufferPointer(start: channel, count: Int(output.frameLength)))
}

private func asrProbeWords(_ text: String) -> [String] {
    let normalized = text.precomposedStringWithCanonicalMapping.lowercased()
    let separators = normalized.unicodeScalars.map { scalar -> Character in
        CharacterSet.letters.contains(scalar) || CharacterSet.decimalDigits.contains(scalar) ? Character(String(scalar)) : " "
    }
    return String(separators).split(whereSeparator: \.isWhitespace).map(String.init)
}

private func asrProbeWER(reference: String, hypothesis: String) -> Double {
    let referenceWords = asrProbeWords(reference)
    let hypothesisWords = asrProbeWords(hypothesis)
    guard !referenceWords.isEmpty else { return 0 }

    var prior = Array(0...hypothesisWords.count)
    for (referenceIndex, referenceWord) in referenceWords.enumerated() {
        var current = [referenceIndex + 1]
        for (hypothesisIndex, hypothesisWord) in hypothesisWords.enumerated() {
            let substitution = prior[hypothesisIndex] + (referenceWord == hypothesisWord ? 0 : 1)
            let insertion = current[hypothesisIndex] + 1
            let deletion = prior[hypothesisIndex + 1] + 1
            current.append(min(substitution, insertion, deletion))
        }
        prior = current
    }
    return Double(prior[hypothesisWords.count]) / Double(referenceWords.count)
}

private func asrProbeContains(_ phrase: [String], in words: [String]) -> Bool {
    guard !phrase.isEmpty, phrase.count <= words.count else { return false }
    return words.indices.contains { start in
        let end = start + phrase.count
        return end <= words.endIndex && Array(words[start..<end]) == phrase
    }
}

private func asrProbeAppendResults(_ results: [ASRProbeResult]) throws {
    var table = """

    ## Nemotron ASR probe

    | Language | Recording | WER | Reference | Transcript |
    | --- | --- | ---: | --- | --- |
    """
    for result in results {
        table += "| \(result.language.rawValue) | \(result.recording) | \(String(format: "%.3f", result.wer)) | \(asrProbeMarkdown(result.reference)) | \(asrProbeMarkdown(result.transcript)) |\n"
    }
    for language in TutorLanguage.allCases {
        let languageResults = results.filter { $0.language == language }
        let meanWER = languageResults.map(\.wer).reduce(0, +) / Double(languageResults.count)
        table += "\nMean \(language.rawValue) WER: \(String(format: "%.3f", meanWER)).\n"
        if language == .spanish, meanWER >= 0.15 {
            table += "Task 6 gate: evaluate the Parakeet v3 fallback for Mexican Spanish.\n"
        }
    }
    try asrProbeAppend(table, to: asrProbeRepositoryRoot().appendingPathComponent("docs/spike/results.md"))
}

private func asrProbeMarkdown(_ text: String) -> String {
    text.replacingOccurrences(of: "|", with: "\\|").replacingOccurrences(of: "\n", with: " ")
}

private func asrProbeAppend(_ text: String, to url: URL) throws {
    let fileManager = FileManager.default
    if !fileManager.fileExists(atPath: url.path) {
        try "# Spike results\n".write(to: url, atomically: true, encoding: .utf8)
    }
    let handle = try FileHandle(forWritingTo: url)
    defer { try? handle.close() }
    try handle.seekToEnd()
    try handle.write(contentsOf: Data(text.utf8))
}

private func asrProbeRepositoryRoot() -> URL {
    URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
}

private enum ASRProbeError: LocalizedError {
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
