import Foundation
import NaturalLanguage
import Testing
import TutorCore
@testable import TutorEngines

@Suite(.enabled(if: ProcessInfo.processInfo.environment["TUTOR_INTEGRATION"] == "1"))
struct QwenProbe {
    @Test func answersPromptSet() async throws {
        let prompts = try qwenProbePromptSet()
        #expect(prompts.english.count == 20)
        #expect(prompts.spanish.count == 20)

        let tutor = try await QwenTutor.load(modelId: ModelCatalog.tutorModelId)
        // Warm-up so the first measured prompt does not pay for Metal kernel compilation.
        for try await _ in tutor.reply(
            system: TutorPrompt.system(for: .english),
            history: [.init(role: .user, text: "Hello")]
        ) {}
        var results: [QwenProbeResult] = []

        for (language, languagePrompts) in [
            (TutorLanguage.english, prompts.english),
            (TutorLanguage.spanish, prompts.spanish),
        ] {
            for prompt in languagePrompts {
                let startedAt = Date()
                var firstTokenSeconds: TimeInterval?
                var response = ""

                for try await chunk in tutor.reply(
                    system: TutorPrompt.system(for: language),
                    history: [.init(role: .user, text: prompt)]
                ) {
                    if firstTokenSeconds == nil {
                        firstTokenSeconds = Date().timeIntervalSince(startedAt)
                    }
                    response += chunk
                }

                let firstToken = try #require(firstTokenSeconds)
                let elapsed = Date().timeIntervalSince(startedAt)
                let tokenCount = await tutor.generatedTokenCount(in: response)
                let generationSeconds = max(elapsed - firstToken, .leastNonzeroMagnitude)
                let tokensPerSecond = Double(tokenCount) / generationSeconds
                results.append(QwenProbeResult(
                    language: language,
                    prompt: prompt,
                    response: response,
                    timeToFirstToken: firstToken,
                    tokensPerSecond: tokensPerSecond
                ))
            }
        }

        try qwenProbeWriteResponses(results)
        try qwenProbeAppendResults(results)

        #expect(results.allSatisfy {
            !$0.response.localizedCaseInsensitiveContains("<think>")
        })
        #expect(qwenProbeMedian(results.map(\.timeToFirstToken)) < 0.5)

        for result in results where result.language == .spanish {
            let recognizer = NLLanguageRecognizer()
            recognizer.processString(result.response)
            #expect(recognizer.dominantLanguage == .spanish)
        }
    }
}

private struct QwenPromptSet: Decodable {
    let english: [String]
    let spanish: [String]

    enum CodingKeys: String, CodingKey {
        case english = "en"
        case spanish = "es"
    }
}

private struct QwenProbeResult {
    let language: TutorLanguage
    let prompt: String
    let response: String
    let timeToFirstToken: TimeInterval
    let tokensPerSecond: Double
}

private enum QwenProbeError: LocalizedError {
    case missingFixture

    var errorDescription: String? {
        switch self {
        case .missingFixture:
            "Could not find tutor-prompts.json in the TutorEnginesTests resources."
        }
    }
}

private func qwenProbePromptSet() throws -> QwenPromptSet {
    let fixtureURL = Bundle.module.url(
        forResource: "tutor-prompts",
        withExtension: "json",
        subdirectory: "Fixtures"
    ) ?? Bundle.module.url(forResource: "tutor-prompts", withExtension: "json")
    guard let fixtureURL else { throw QwenProbeError.missingFixture }
    return try JSONDecoder().decode(QwenPromptSet.self, from: Data(contentsOf: fixtureURL))
}

private func qwenProbeWriteResponses(_ results: [QwenProbeResult]) throws {
    var markdown = "# Tutor responses\n"
    for language in TutorLanguage.allCases {
        markdown += "\n## \(language == .english ? "English" : "Mexican Spanish")\n"
        for (index, result) in results.filter({ $0.language == language }).enumerated() {
            markdown += "\n### Prompt \(index + 1)\n\nLearner: \(result.prompt)\n\nTutor: \(result.response)\n"
        }
    }
    try markdown.write(
        to: qwenProbeRepositoryRoot().appendingPathComponent("docs/spike/tutor-responses.md"),
        atomically: true,
        encoding: .utf8
    )
}

private func qwenProbeAppendResults(_ results: [QwenProbeResult]) throws {
    let heading = "## Qwen tutor probe"
    var section = "\(heading)\n\n"
    section += "Model \(ModelCatalog.tutorModelId), temperature 0.6, max 300 tokens, thinking disabled. "
    section += "Tokens/s is generated tokens over the time after the first token.\n\n"
    section += "| Language | Prompt | TTFT | Tokens/s |\n| --- | --- | ---: | ---: |\n"
    for result in results {
        section += String(
            format: "| %@ | %@ | %.3f s | %.2f |\n",
            result.language.rawValue,
            qwenProbeMarkdown(result.prompt),
            result.timeToFirstToken,
            result.tokensPerSecond
        )
    }
    section += String(
        format: "\nMedian TTFT %.3f s; median tokens/s %.2f.\n",
        qwenProbeMedian(results.map(\.timeToFirstToken)),
        qwenProbeMedian(results.map(\.tokensPerSecond))
    )

    // Replace the previous run's section so re-running the probe stays idempotent.
    let url = qwenProbeRepositoryRoot().appendingPathComponent("docs/spike/results.md")
    var existing = (try? String(contentsOf: url, encoding: .utf8)) ?? "# Spike results\n"
    if let start = existing.range(of: heading) {
        let end = existing[start.upperBound...].range(of: "\n## ")?.lowerBound ?? existing.endIndex
        existing.removeSubrange(start.lowerBound..<end)
    }
    existing = existing.trimmingCharacters(in: .newlines) + "\n\n" + section
    try existing.write(to: url, atomically: true, encoding: .utf8)
}

private func qwenProbeMedian(_ values: [TimeInterval]) -> TimeInterval {
    let sorted = values.sorted()
    let middle = sorted.count / 2
    return sorted.count.isMultiple(of: 2)
        ? (sorted[middle - 1] + sorted[middle]) / 2
        : sorted[middle]
}

private func qwenProbeMarkdown(_ text: String) -> String {
    text.replacingOccurrences(of: "|", with: "\\|").replacingOccurrences(of: "\n", with: " ")
}

private func qwenProbeRepositoryRoot() -> URL {
    URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
}
