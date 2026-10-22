import SwiftUI
import TutorEngines

struct SetupView: View {
    let progress: Double
    let title: String
    let alreadyInstalled: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text(alreadyInstalled ? "Getting the tutor ready" : "Setting up your tutor")
                .font(.title.bold())

            if !alreadyInstalled {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(ModelInstaller.steps, id: \.title) { step in
                        HStack {
                            Text(step.title)
                            Spacer()
                            Text(Self.sizeText(step.approxBytes))
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                    }
                }
                .frame(maxWidth: 360)
            }

            VStack(alignment: .leading, spacing: 6) {
                ProgressView(value: min(max(progress, 0), 1))
                    .frame(maxWidth: 360)
                Text(title.isEmpty ? " " : "\(title)…")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Text("Everything runs on this Mac. After this download, the tutor works offline.")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }

    static func sizeText(_ bytes: Int64) -> String {
        "about " + ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
}
