import SwiftUI

@main struct MyApp: App {
    @State private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            ContentView(model: model)
        }
        .commands {
            CommandGroup(after: .toolbar) {
                Toggle("Timing Panel", isOn: $model.showTimingPanel)
                    .keyboardShortcut("t", modifiers: [.command, .shift])
            }
        }
    }
}
