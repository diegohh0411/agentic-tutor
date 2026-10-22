import AppKit
import SwiftUI
import TutorCore

struct ConversationView: View {
    @Bindable var model: AppModel
    @State private var draft = ""
    @FocusState private var focus: Field?

    private enum Field { case root, text }

    var body: some View {
        VStack(spacing: 16) {
            header
            banners
            captions
            expressionView
            Spacer(minLength: 0)
            if model.isHolding {
                Text(Strings.takeYourTime(model.language))
                    .foregroundStyle(.secondary)
            }
            typedInput
        }
        .padding(24)
        .frame(minWidth: 560, minHeight: 460)
        .overlay(alignment: .topTrailing) {
            if model.showTimingPanel {
                TimingPanel(metrics: model.lastMetrics)
                    .padding(12)
            }
        }
        .focusable()
        .focused($focus, equals: .root)
        .focusEffectDisabled()
        .onKeyPress(.space, phases: [.down, .up]) { press in
            // Space only holds the turn open when the text field is not being typed in.
            guard focus != .text, model.isRunning else { return .ignored }
            model.setHold(press.phase == .down)
            return .handled
        }
        .onAppear { focus = .root }
    }

    private var header: some View {
        HStack {
            Button(model.isRunning ? Strings.stop(model.language) : Strings.start(model.language)) {
                if model.isRunning { model.stop() } else { Task { await model.start() } }
            }
            .keyboardShortcut(.return, modifiers: .command)
            .controlSize(.large)

            Text(Strings.stateName(model.state, model.language))
                .font(.headline)
                .foregroundStyle(stateColor)

            Spacer()

            Picker("Language", selection: $model.language) {
                Text("English").tag(TutorLanguage.english)
                Text("Español").tag(TutorLanguage.spanish)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(width: 180)
        }
    }

    @ViewBuilder private var banners: some View {
        if model.micDenied {
            HStack {
                Text("Microphone access is off. Turn it on in System Settings › Privacy & Security › Microphone.")
                Button("Open System Settings") { Self.openMicrophoneSettings() }
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.orange.opacity(0.2), in: RoundedRectangle(cornerRadius: 8))
        }
        if model.needsHeadphones {
            Text("For best results, please use headphones.")
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.yellow.opacity(0.2), in: RoundedRectangle(cornerRadius: 8))
        }
        if let message = model.errorMessage {
            Text(message)
                .foregroundStyle(.red)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var captions: some View {
        VStack(alignment: .leading, spacing: 10) {
            caption(Strings.you(model.language), model.userCaption)
            caption(Strings.tutor(model.language), model.tutorCaption)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func caption(_ label: String, _ text: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.caption).foregroundStyle(.secondary)
            Text(text.isEmpty ? " " : text).font(.title3)
        }
    }

    @ViewBuilder private var expressionView: some View {
        if let expression = model.expression {
            Text(expression)
                .font(.system(size: 44, weight: .medium, design: .monospaced))
                .minimumScaleFactor(0.4)
                .lineLimit(2)
                .padding()
                .frame(maxWidth: .infinity)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 12))
        }
    }

    private var typedInput: some View {
        TextField(Strings.typePrompt(model.language), text: $draft)
            .textFieldStyle(.roundedBorder)
            .focused($focus, equals: .text)
            .disabled(!model.isRunning)
            .onSubmit {
                let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !text.isEmpty else { return }
                model.send(text)
                draft = ""
            }
    }

    private var stateColor: Color {
        switch model.state {
        case .idle: .secondary
        case .listening: .green
        case .thinking: .orange
        case .speaking: .blue
        }
    }

    private static func openMicrophoneSettings() {
        guard let url = URL(string:
            "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone")
        else { return }
        NSWorkspace.shared.open(url)
    }
}

private enum Strings {
    static func stateName(_ state: ConversationState, _ language: TutorLanguage) -> String {
        switch (state, language) {
        case (.idle, .english): "Ready"
        case (.idle, .spanish): "Listo"
        case (.listening, .english): "Listening"
        case (.listening, .spanish): "Escuchando"
        case (.thinking, .english): "Thinking"
        case (.thinking, .spanish): "Pensando"
        case (.speaking, .english): "Speaking"
        case (.speaking, .spanish): "Hablando"
        }
    }

    static func start(_ language: TutorLanguage) -> String { language == .english ? "Start" : "Empezar" }
    static func stop(_ language: TutorLanguage) -> String { language == .english ? "Stop" : "Detener" }
    static func you(_ language: TutorLanguage) -> String { language == .english ? "You" : "Tú" }
    static func tutor(_ language: TutorLanguage) -> String { language == .english ? "Tutor" : "Tutor" }
    static func takeYourTime(_ language: TutorLanguage) -> String {
        language == .english ? "Take your time…" : "Tómate tu tiempo…"
    }
    static func typePrompt(_ language: TutorLanguage) -> String {
        language == .english ? "Or type a question" : "O escribe una pregunta"
    }
}
