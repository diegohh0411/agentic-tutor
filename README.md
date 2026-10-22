# AgenticTutor

An experimental native macOS voice math tutor. Speak in English or Spanish and receive spoken tutoring replies, with speech recognition, language generation, and speech synthesis running locally.

The app uses SwiftUI, AVAudioEngine, Silero VAD, Smart Turn, Nemotron streaming ASR, Qwen3.5-4B through MLX, and Phonon speech synthesis. Models download during initial setup and are cached for offline use.

## Build and run

You need an Apple Silicon Mac, Xcode with the macOS 27 SDK (the app currently targets macOS 27), and Rust/Cargo for exporting the bundled voice model. The TutorKit packages target macOS 15 or later.

1. Accept the model terms for `gradium/phonon-40m-multilingual` on Hugging Face and supply a Hugging Face access token through the `HF_TOKEN` environment variable.
2. Run `bash scripts/export-phonon.sh` from the repository root. It exports the voice assets into `AgenticTutor/PhononModels/`. These large generated assets are excluded from Git.
3. Open `AgenticTutor.xcodeproj`, select the `AgenticTutor` scheme, and run. Adjust signing settings for your development environment if needed.
4. Allow microphone access, let initial model setup complete, then select a language and click Start.

The initial downloads total roughly 3.2 GB. Model weights and dependencies have their own licenses and terms; consult their upstream repositories before redistribution.

This is an MVP under active development. Automated audio and conversation tests pass, but the latest microphone timing fix still needs confirmation in a live conversation.

## Tests

The core conversation logic has no model dependencies:

```sh
swift test --package-path TutorKit/Core
```

For audio and engine tests, run the `TutorKit-Package` scheme in Xcode, or from the `TutorKit` directory:

```sh
xcodebuild test -scheme TutorKit-Package -destination 'platform=macOS'
```

Some model probes require locally installed models, audio fixtures, and `TEST_RUNNER_TUTOR_INTEGRATION=1`. See `TutorKit/Tests/TutorEnginesTests` for each probe's prerequisites.

## Project layout

- `AgenticTutor/`: SwiftUI application and setup flow.
- `TutorKit/Core/`: Conversation state machine, turn taking, language policy, and unit tests.
- `TutorKit/Sources/`: Microphone/playback integration and local model adapters.
- `docs/`: Architecture research, MVP design, and recorded probe results.
- `scripts/export-phonon.sh`: Local voice model export.
