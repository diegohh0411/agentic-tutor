import SwiftUI

struct ContentView: View {
    @Bindable var model: AppModel

    var body: some View {
        Group {
            switch model.phase {
            case let .setup(progress, title):
                SetupView(progress: progress, title: title, alreadyInstalled: model.wasInstalledAtLaunch)
            case .ready:
                ConversationView(model: model)
            case let .failed(message):
                VStack(spacing: 12) {
                    Text("The tutor could not start.").font(.title2.bold())
                    Text(message).foregroundStyle(.secondary)
                    Button("Try again") { Task { await model.loadModels() } }
                }
                .padding(32)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .task { await model.loadModels() }
    }
}
