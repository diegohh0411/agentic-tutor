import Foundation

public struct TurnConfig: Sendable {
    public var vadThreshold: Float = 0.5
    public var onsetChunks = 2
    public var pauseTrigger: TimeInterval = 0.40
    public var recheckInterval: TimeInterval = 0.12
    public var completeThreshold: Float = 0.6
    public var confirmCount = 2
    public var silenceFallback: TimeInterval = 3.0
    public var bargeInConfirm: TimeInterval = 0.384
    public var bargeInRelease: TimeInterval = 0.30

    public init() {}
}

public enum TurnInput: Sendable {
    case vad(Float, at: TimeInterval)
    case verdict(Float, at: TimeInterval)
    case asrWords(at: TimeInterval)
    case hold(Bool, at: TimeInterval)
    case tutorSpeaking(Bool)
}

public enum TurnEndReason: Sendable, Equatable {
    case smartTurn
    case silenceFallback
}

public enum TurnOutput: Sendable, Equatable {
    case userSpeechStarted(at: TimeInterval)
    case checkTurn(at: TimeInterval)
    case turnEnded(at: TimeInterval, reason: TurnEndReason, silenceAllowance: TimeInterval)
    case duckTutor(at: TimeInterval)
    case bargeIn(at: TimeInterval)
    case unduckTutor(at: TimeInterval)
}

/// A deterministic turn-taking state machine driven entirely by timestamped inputs.
public struct TurnTaker {
    private static let chunkDuration: TimeInterval = 0.032

    private let config: TurnConfig
    private var tutorIsSpeaking = false
    private var isHolding = false
    private var hasOpenTurn = false
    private var wasBargeIn = false

    private var speechRunStart: TimeInterval?
    private var speechRunCount = 0
    private var previousVADTime: TimeInterval?
    private var lastSpeechEnd: TimeInterval?
    private var silenceDuration: TimeInterval = 0
    private var lastCheckSilenceDuration: TimeInterval?
    private var speechGeneration = 0
    private var lastCheckSpeechGeneration: Int?
    private var consecutiveCompleteVerdicts = 0

    private var duckIsActive = false
    private var pendingBargeInOnset: TimeInterval?

    public init(config: TurnConfig = .init()) {
        self.config = config
    }

    public mutating func process(_ input: TurnInput) -> [TurnOutput] {
        switch input {
        case let .vad(probability, at: time):
            return processVAD(probability, at: time)

        case let .verdict(probability, at: time):
            return processVerdict(probability, at: time)

        case let .asrWords(at: time):
            return confirmBargeIn(at: time)

        case let .hold(isHeld, at: time):
            isHolding = isHeld
            if !isHeld, hasOpenTurn {
                // Holding means the user may be thinking; only post-release silence counts.
                lastSpeechEnd = time
                silenceDuration = 0
                lastCheckSilenceDuration = nil
                consecutiveCompleteVerdicts = 0
            }
            return []

        case let .tutorSpeaking(isSpeaking):
            tutorIsSpeaking = isSpeaking
            return []
        }
    }

    private mutating func processVAD(_ probability: Float, at time: TimeInterval) -> [TurnOutput] {
        let isSpeech = probability >= config.vadThreshold
        let isContiguous = previousVADTime.map { abs(time - $0 - Self.chunkDuration) < 0.000_001 } ?? true
        previousVADTime = time

        guard isSpeech else {
            speechRunStart = nil
            speechRunCount = 0
            return processSilence(at: time)
        }

        if isContiguous, let start = speechRunStart {
            speechRunStart = start
            speechRunCount += 1
        } else {
            speechRunStart = time
            speechRunCount = 1
        }

        lastSpeechEnd = time + Self.chunkDuration
        silenceDuration = 0
        lastCheckSilenceDuration = nil
        speechGeneration &+= 1
        consecutiveCompleteVerdicts = 0

        var output: [TurnOutput] = []
        if !hasOpenTurn, pendingBargeInOnset == nil,
           speechRunCount >= max(1, config.onsetChunks), let onset = speechRunStart {
            if tutorIsSpeaking {
                duckIsActive = true
                pendingBargeInOnset = onset
                output.append(.duckTutor(at: time))
            } else {
                startUserTurn(bargeIn: false)
                output.append(.userSpeechStarted(at: onset))
            }
        }

        if let onset = pendingBargeInOnset,
           time + Self.chunkDuration - onset >= config.bargeInConfirm {
            output += confirmBargeIn(at: time)
        }

        return output
    }

    private mutating func processSilence(at time: TimeInterval) -> [TurnOutput] {
        guard let lastSpeechEnd else { return [] }

        silenceDuration = max(0, time + Self.chunkDuration - lastSpeechEnd)

        if pendingBargeInOnset != nil, duckIsActive, silenceDuration >= config.bargeInRelease {
            duckIsActive = false
            pendingBargeInOnset = nil
            self.lastSpeechEnd = nil
            silenceDuration = 0
            return [.unduckTutor(at: time)]
        }

        guard hasOpenTurn, !isHolding else { return [] }

        if silenceDuration >= config.silenceFallback {
            return endTurn(at: time, reason: .silenceFallback)
        }

        guard !tutorIsSpeaking || wasBargeIn else { return [] }
        guard silenceDuration >= config.pauseTrigger else { return [] }
        if let lastCheckSilenceDuration,
           silenceDuration - lastCheckSilenceDuration < config.recheckInterval {
            return []
        }

        lastCheckSilenceDuration = silenceDuration
        lastCheckSpeechGeneration = speechGeneration
        return [.checkTurn(at: time)]
    }

    private mutating func processVerdict(_ probability: Float, at time: TimeInterval) -> [TurnOutput] {
        guard hasOpenTurn, !isHolding, (!tutorIsSpeaking || wasBargeIn) else { return [] }
        // A Smart Turn result is only valid for the pause that produced its check.
        // Preserve support for integrations that deliver a first verdict before a
        // check, but once a check has been emitted speech must be followed by a
        // fresh check before another verdict can count.
        guard lastCheckSpeechGeneration.map({ $0 == speechGeneration }) ?? true else { return [] }

        if probability >= config.completeThreshold {
            consecutiveCompleteVerdicts += 1
        } else {
            consecutiveCompleteVerdicts = 0
        }

        guard consecutiveCompleteVerdicts >= max(1, config.confirmCount) else { return [] }
        return endTurn(at: time, reason: .smartTurn)
    }

    private mutating func confirmBargeIn(at time: TimeInterval) -> [TurnOutput] {
        guard let onset = pendingBargeInOnset, duckIsActive else { return [] }

        pendingBargeInOnset = nil
        startUserTurn(bargeIn: true)
        return [.bargeIn(at: time), .userSpeechStarted(at: onset)]
    }

    private mutating func startUserTurn(bargeIn: Bool) {
        hasOpenTurn = true
        wasBargeIn = bargeIn
        silenceDuration = 0
        lastCheckSilenceDuration = nil
        lastCheckSpeechGeneration = nil
        consecutiveCompleteVerdicts = 0
    }

    private mutating func endTurn(at time: TimeInterval, reason: TurnEndReason) -> [TurnOutput] {
        let output = TurnOutput.turnEnded(
            at: time,
            reason: reason,
            silenceAllowance: silenceDuration
        )

        hasOpenTurn = false
        wasBargeIn = false
        speechRunStart = nil
        speechRunCount = 0
        lastSpeechEnd = nil
        silenceDuration = 0
        lastCheckSilenceDuration = nil
        consecutiveCompleteVerdicts = 0
        return [output]
    }
}
