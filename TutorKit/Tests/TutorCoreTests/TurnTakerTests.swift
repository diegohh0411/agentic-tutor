import Foundation
import Testing
@testable import TutorCore

private let chunkDuration: TimeInterval = 0.032

@discardableResult
private func feed(
    _ probabilities: [Float],
    from t0: TimeInterval,
    into turnTaker: inout TurnTaker
) -> [TurnOutput] {
    probabilities.enumerated().flatMap { offset, probability in
        turnTaker.process(.vad(probability, at: t0 + (Double(offset) * chunkDuration)))
    }
}

@Test func onsetAfterTwoSpeechChunks() {
    var turnTaker = TurnTaker()

    let output = feed([0.9, 0.9], from: 0, into: &turnTaker)

    #expect(output == [.userSpeechStarted(at: 0)])
}

@Test func pauseTriggersCheckAfter400ms() {
    var turnTaker = TurnTaker()
    _ = feed([0.9, 0.9], from: 0, into: &turnTaker)

    let output = feed(Array(repeating: 0, count: 24), from: 0.064, into: &turnTaker)
    let checks = output.compactMap { output -> TimeInterval? in
        guard case let .checkTurn(at: time) = output else { return nil }
        return time
    }

    #expect(checks.count >= 2)
    #expect(checks[0] >= 0.40)
    #expect(checks[1] - checks[0] >= 0.12)
}

@Test func twoCompleteVerdictsEndTurn() {
    var endsAfterTwo = TurnTaker()
    _ = feed([0.9, 0.9], from: 0, into: &endsAfterTwo)
    let completeOutput = endsAfterTwo.process(.verdict(0.7, at: 0.1))
        + endsAfterTwo.process(.verdict(0.7, at: 0.2))

    #expect(completeOutput.contains { output in
        guard case let .turnEnded(_, reason, _) = output else { return false }
        return reason == .smartTurn
    })

    var resetBySpeech = TurnTaker()
    _ = feed([0.9, 0.9], from: 0, into: &resetBySpeech)
    _ = resetBySpeech.process(.verdict(0.7, at: 0.1))
    _ = resetBySpeech.process(.vad(0.9, at: 0.2))
    let resetOutput = resetBySpeech.process(.verdict(0.7, at: 0.3))

    #expect(!resetOutput.contains { output in
        guard case .turnEnded = output else { return false }
        return true
    })
}

@Test func staleVerdictAfterSpeechResumesIsIgnored() {
    var turnTaker = TurnTaker()
    _ = feed([0.9, 0.9], from: 0, into: &turnTaker)
    let initialPause = feed(Array(repeating: 0, count: 13), from: 0.064, into: &turnTaker)
    #expect(initialPause.contains { output in
        guard case .checkTurn = output else { return false }
        return true
    })

    _ = turnTaker.process(.vad(0.9, at: 0.480))
    #expect(turnTaker.process(.verdict(0.9, at: 0.512)).isEmpty)

    let resumedPause = feed(Array(repeating: 0, count: 13), from: 0.512, into: &turnTaker)
    #expect(resumedPause.contains { output in
        guard case .checkTurn = output else { return false }
        return true
    })
    #expect(turnTaker.process(.verdict(0.9, at: 0.896)).isEmpty)

    let output = turnTaker.process(.verdict(0.9, at: 0.928))
    #expect(output.contains { output in
        guard case let .turnEnded(_, reason, _) = output else { return false }
        return reason == .smartTurn
    })
}

@Test func turnEndCarriesSilenceAllowance() {
    var turnTaker = TurnTaker()
    _ = feed([0.9, 0.9], from: 0.936, into: &turnTaker)

    _ = feed(Array(repeating: 0, count: 13), from: 1.0, into: &turnTaker)
    #expect(turnTaker.process(.verdict(0.9, at: 1.384)).isEmpty)

    _ = feed(Array(repeating: 0, count: 4), from: 1.416, into: &turnTaker)
    let output = turnTaker.process(.verdict(0.9, at: 1.512))
    let silenceAllowance = output.compactMap { output -> TimeInterval? in
        guard case let .turnEnded(_, reason, allowance) = output, reason == .smartTurn else {
            return nil
        }
        return allowance
    }

    #expect(silenceAllowance.count == 1)
    #expect(abs(silenceAllowance[0] - ((1.512 + chunkDuration) - 1.0)) < 0.001)
}

@Test func holdSuppressesTurnEnd() {
    var turnTaker = TurnTaker()
    _ = feed([0.9, 0.9], from: 0, into: &turnTaker)
    _ = turnTaker.process(.hold(true, at: 0.064))

    let heldOutput = feed(Array(repeating: 0, count: 157), from: 0.064, into: &turnTaker)
    #expect(!heldOutput.contains { output in
        switch output {
        case .checkTurn, .turnEnded: true
        default: false
        }
    })

    _ = turnTaker.process(.hold(false, at: 5.1))
    let releasedOutput = feed(Array(repeating: 0, count: 94), from: 5.1, into: &turnTaker)
    #expect(releasedOutput.contains { output in
        guard case let .turnEnded(_, reason, _) = output else { return false }
        return reason == .silenceFallback
    })
}

@Test func silenceFallbackAfter3s() {
    var turnTaker = TurnTaker()
    _ = feed([0.9, 0.9], from: 0, into: &turnTaker)

    let output = feed(Array(repeating: 0.1, count: 94), from: 0.064, into: &turnTaker)

    #expect(output.contains { output in
        guard case let .turnEnded(_, reason, silenceAllowance) = output else { return false }
        return reason == .silenceFallback && silenceAllowance >= 3.0
    })
}

@Test func bargeInDucksThenConfirms() {
    var turnTaker = TurnTaker()
    _ = turnTaker.process(.tutorSpeaking(true))

    let initialOutput = feed([0.9, 0.9], from: 1.0, into: &turnTaker)
    let confirmedOutput = feed(Array(repeating: 0.9, count: 10), from: 1.064, into: &turnTaker)
    let output = initialOutput + confirmedOutput

    #expect(output.contains(.duckTutor(at: 1.032)))
    #expect(output.contains { output in
        guard case let .bargeIn(at: time) = output else { return false }
        return time <= 1.416
    })
    #expect(output.contains(.userSpeechStarted(at: 1.0)))
}

@Test func bargeInConfirmsEarlyOnASRWords() {
    var turnTaker = TurnTaker()
    _ = turnTaker.process(.tutorSpeaking(true))
    _ = feed([0.9, 0.9], from: 1.0, into: &turnTaker)

    let output = turnTaker.process(.asrWords(at: 1.064))

    #expect(output == [.bargeIn(at: 1.064), .userSpeechStarted(at: 1.0)])
}

@Test func coughIsReleased() {
    var turnTaker = TurnTaker()
    _ = turnTaker.process(.tutorSpeaking(true))
    let speechOutput = feed([0.9, 0.9, 0.9], from: 0, into: &turnTaker)
    let silenceOutput = feed(Array(repeating: 0, count: 10), from: 0.096, into: &turnTaker)
    let output = speechOutput + silenceOutput

    #expect(output.contains(.duckTutor(at: 0.032)))
    #expect(output.contains { output in
        guard case .unduckTutor = output else { return false }
        return true
    })
    #expect(!output.contains { output in
        guard case .bargeIn = output else { return false }
        return true
    })
}
