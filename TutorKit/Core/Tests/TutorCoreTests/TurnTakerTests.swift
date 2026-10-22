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

private func lastCheckTime(in output: [TurnOutput]) -> TimeInterval? {
    output.reversed().compactMap { output in
        guard case let .checkTurn(at: time) = output else { return nil }
        return time
    }.first
}

@Test func onsetAfterTwoSpeechChunks() {
    var turnTaker = TurnTaker()

    let output = feed([0.9, 0.9], from: 0, into: &turnTaker)

    #expect(output == [.userSpeechStarted(at: 0)])
}

@Test func onsetSurvivesMicrophoneCallbackJitter() {
    var turnTaker = TurnTaker()
    #expect(turnTaker.process(.vad(0.9, at: 100)).isEmpty)
    #expect(turnTaker.process(.vad(0.9, at: 100.0335)) == [.userSpeechStarted(at: 100)])
}

@Test func onsetSurvivesChunksDeliveredInOneCallback() {
    var turnTaker = TurnTaker()
    #expect(turnTaker.process(.vad(0.9, at: 100)).isEmpty)
    #expect(turnTaker.process(.vad(0.9, at: 100)) == [.userSpeechStarted(at: 100)])
}

@Test func onsetDoesNotJoinSpeechAcrossACaptureGap() {
    var turnTaker = TurnTaker()
    #expect(turnTaker.process(.vad(0.9, at: 100)).isEmpty)
    #expect(turnTaker.process(.vad(0.9, at: 101)).isEmpty)
    #expect(turnTaker.process(.vad(0.9, at: 101.032)) == [.userSpeechStarted(at: 101)])
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
    let firstPause = feed(Array(repeating: 0, count: 13), from: 0.064, into: &endsAfterTwo)
    guard let firstCheck = lastCheckTime(in: firstPause) else {
        Issue.record("Expected an initial Smart Turn check")
        return
    }
    #expect(endsAfterTwo.process(.verdict(0.7, at: firstCheck)).isEmpty)

    let secondPause = feed(Array(repeating: 0, count: 4), from: 0.480, into: &endsAfterTwo)
    guard let secondCheck = lastCheckTime(in: secondPause) else {
        Issue.record("Expected a Smart Turn recheck")
        return
    }
    let completeOutput = endsAfterTwo.process(.verdict(0.7, at: secondCheck))

    #expect(completeOutput.contains { output in
        guard case let .turnEnded(_, reason, _) = output else { return false }
        return reason == .smartTurn
    })

    var resetBySpeech = TurnTaker()
    _ = feed([0.9, 0.9], from: 0, into: &resetBySpeech)
    let initialPause = feed(Array(repeating: 0, count: 13), from: 0.064, into: &resetBySpeech)
    guard let initialCheck = lastCheckTime(in: initialPause) else {
        Issue.record("Expected an initial Smart Turn check")
        return
    }
    _ = resetBySpeech.process(.verdict(0.7, at: initialCheck))
    _ = resetBySpeech.process(.vad(0.9, at: 0.480))
    let resumedPause = feed(Array(repeating: 0, count: 13), from: 0.512, into: &resetBySpeech)
    guard let resumedCheck = lastCheckTime(in: resumedPause) else {
        Issue.record("Expected a Smart Turn check after speech resumed")
        return
    }
    let resetOutput = resetBySpeech.process(.verdict(0.7, at: resumedCheck))

    #expect(!resetOutput.contains { output in
        guard case .turnEnded = output else { return false }
        return true
    })
}

@Test func staleVerdictAfterSpeechResumesIsIgnored() {
    var turnTaker = TurnTaker()
    _ = feed([0.9, 0.9], from: 0, into: &turnTaker)
    let initialPause = feed(Array(repeating: 0, count: 13), from: 0.064, into: &turnTaker)
    guard let initialCheck = lastCheckTime(in: initialPause) else {
        Issue.record("Expected an initial Smart Turn check")
        return
    }

    _ = turnTaker.process(.vad(0.9, at: 0.480))
    #expect(turnTaker.process(.verdict(0.9, at: initialCheck)).isEmpty)

    let resumedPause = feed(Array(repeating: 0, count: 13), from: 0.512, into: &turnTaker)
    guard let resumedCheck = lastCheckTime(in: resumedPause) else {
        Issue.record("Expected a Smart Turn check after speech resumed")
        return
    }
    #expect(turnTaker.process(.verdict(0.9, at: resumedCheck)).isEmpty)

    let recheck = feed(Array(repeating: 0, count: 4), from: 0.928, into: &turnTaker)
    guard let recheckTime = lastCheckTime(in: recheck) else {
        Issue.record("Expected a Smart Turn recheck")
        return
    }

    let output = turnTaker.process(.verdict(0.9, at: recheckTime))
    #expect(output.contains { output in
        guard case let .turnEnded(_, reason, _) = output else { return false }
        return reason == .smartTurn
    })
}

@Test func verdictForOlderCheckIsIgnored() {
    var turnTaker = TurnTaker()
    _ = feed([0.9, 0.9], from: 0, into: &turnTaker)

    let initialPause = feed(Array(repeating: 0, count: 13), from: 0.064, into: &turnTaker)
    guard let checkA = lastCheckTime(in: initialPause) else {
        Issue.record("Expected check A")
        return
    }
    let firstRecheck = feed(Array(repeating: 0, count: 4), from: 0.480, into: &turnTaker)
    guard let checkB = lastCheckTime(in: firstRecheck) else {
        Issue.record("Expected check B")
        return
    }

    #expect(turnTaker.process(.verdict(0.9, at: checkA)).isEmpty)
    #expect(turnTaker.process(.verdict(0.9, at: checkB)).isEmpty)

    let secondRecheck = feed(Array(repeating: 0, count: 4), from: 0.608, into: &turnTaker)
    guard let checkC = lastCheckTime(in: secondRecheck) else {
        Issue.record("Expected check C")
        return
    }
    let output = turnTaker.process(.verdict(0.9, at: checkC))

    #expect(output.contains { output in
        guard case let .turnEnded(_, reason, _) = output else { return false }
        return reason == .smartTurn
    })
}

@Test func duplicateVerdictForCheckIsIgnored() {
    var turnTaker = TurnTaker()
    _ = feed([0.9, 0.9], from: 0, into: &turnTaker)

    let pause = feed(Array(repeating: 0, count: 13), from: 0.064, into: &turnTaker)
    guard let checkTime = lastCheckTime(in: pause) else {
        Issue.record("Expected a Smart Turn check")
        return
    }

    #expect(turnTaker.process(.verdict(0.9, at: checkTime)).isEmpty)
    #expect(turnTaker.process(.verdict(0.9, at: checkTime)).isEmpty)
}

@Test func turnEndCarriesSilenceAllowance() {
    var turnTaker = TurnTaker()
    _ = feed([0.9, 0.9], from: 0.936, into: &turnTaker)

    let initialPause = feed(Array(repeating: 0, count: 13), from: 1.0, into: &turnTaker)
    guard let initialCheck = lastCheckTime(in: initialPause) else {
        Issue.record("Expected an initial Smart Turn check")
        return
    }
    #expect(turnTaker.process(.verdict(0.9, at: initialCheck)).isEmpty)

    let recheck = feed(Array(repeating: 0, count: 4), from: 1.416, into: &turnTaker)
    guard let recheckTime = lastCheckTime(in: recheck) else {
        Issue.record("Expected a Smart Turn recheck")
        return
    }
    let output = turnTaker.process(.verdict(0.9, at: recheckTime))
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
