import Darwin
import Foundation

public struct TurnMetrics: Sendable, Equatable {
    public var silenceAllowance: TimeInterval?
    public var asrFinalize: TimeInterval?
    public var llmFirstToken: TimeInterval?
    public var ttsFirstAudio: TimeInterval?
    public var replyLatency: TimeInterval?
    public var bargeInDuck: TimeInterval?
    public var footprintBytes: UInt64
}

public struct LatencyRecorder {
    public enum Mark: Sendable {
        case speechOnset
        case turnEnded(silenceAllowance: TimeInterval)
        case asrFinal
        case llmFirstToken
        case ttsFirstChunk
        case firstEnqueue(outputLatency: TimeInterval)
        case duck
    }

    private var speechOnset: TimeInterval?
    private var turnEnded: (time: TimeInterval, silenceAllowance: TimeInterval)?
    private var asrFinal: TimeInterval?
    private var llmFirstToken: TimeInterval?
    private var ttsFirstChunk: TimeInterval?
    private var firstEnqueue: (time: TimeInterval, outputLatency: TimeInterval)?
    private var duck: TimeInterval?

    public init() {}

    public mutating func mark(_ mark: Mark, at time: TimeInterval) {
        switch mark {
        case .speechOnset:
            speechOnset = time
        case let .turnEnded(silenceAllowance):
            turnEnded = (time, silenceAllowance)
        case .asrFinal:
            asrFinal = time
        case .llmFirstToken:
            llmFirstToken = time
        case .ttsFirstChunk:
            ttsFirstChunk = time
        case let .firstEnqueue(outputLatency):
            firstEnqueue = (time, outputLatency)
        case .duck:
            duck = time
        }
    }

    public mutating func close(footprint: UInt64) -> TurnMetrics {
        let metrics = TurnMetrics(
            silenceAllowance: turnEnded?.silenceAllowance,
            asrFinalize: duration(from: turnEnded?.time, to: asrFinal),
            llmFirstToken: duration(from: asrFinal, to: llmFirstToken),
            ttsFirstAudio: duration(from: llmFirstToken, to: ttsFirstChunk),
            replyLatency: replyLatency(),
            bargeInDuck: duration(from: speechOnset, to: duck),
            footprintBytes: footprint
        )
        reset()
        return metrics
    }

    private func duration(from start: TimeInterval?, to end: TimeInterval?) -> TimeInterval? {
        guard let start, let end else { return nil }
        return end - start
    }

    private func replyLatency() -> TimeInterval? {
        guard let turnEnded, let firstEnqueue else { return nil }
        return firstEnqueue.time + firstEnqueue.outputLatency - turnEnded.time
    }

    private mutating func reset() {
        speechOnset = nil
        turnEnded = nil
        asrFinal = nil
        llmFirstToken = nil
        ttsFirstChunk = nil
        firstEnqueue = nil
        duck = nil
    }
}

public func currentFootprintBytes() -> UInt64 {
    var info = task_vm_info_data_t()
    var count = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<integer_t>.size)
    let result = withUnsafeMutablePointer(to: &info) { pointer in
        pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
            task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
        }
    }
    return result == KERN_SUCCESS ? info.phys_footprint : 0
}
