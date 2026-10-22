import SwiftUI
import TutorCore

struct TimingPanel: View {
    let metrics: TurnMetrics?

    private static let gigabyte = 1_000_000_000.0
    private static let footprintLimitGB = 12.0
    private static let replyLatencyLimit = 1.0
    private static let bargeInLimit = 0.3

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Timing").font(.headline)
            row("Silence allowance", metrics?.silenceAllowance)
            row("Speech to text", metrics?.asrFinalize)
            row("First token", metrics?.llmFirstToken)
            row("First audio", metrics?.ttsFirstAudio)
            row("Reply latency", metrics?.replyLatency, limit: Self.replyLatencyLimit)
            row("Barge-in duck", metrics?.bargeInDuck, limit: Self.bargeInLimit)
            footprintRow
        }
        .font(.system(.caption, design: .monospaced))
        .padding(10)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
    }

    private func row(_ name: String, _ seconds: TimeInterval?, limit: Double? = nil) -> some View {
        HStack {
            Text(name)
            Spacer(minLength: 16)
            Text(seconds.map { String(format: "%.0f ms", $0 * 1000) } ?? "-")
                .foregroundStyle(isOver(seconds, limit) ? Color.red : Color.primary)
        }
    }

    private var footprintRow: some View {
        let gigabytes = metrics.map { Double($0.footprintBytes) / Self.gigabyte }
        return HStack {
            Text("Memory")
            Spacer(minLength: 16)
            Text(gigabytes.map { String(format: "%.1f GB", $0) } ?? "-")
                .foregroundStyle(isOver(gigabytes, Self.footprintLimitGB) ? Color.red : Color.primary)
        }
    }

    private func isOver(_ value: Double?, _ limit: Double?) -> Bool {
        guard let value, let limit else { return false }
        return value > limit
    }
}
