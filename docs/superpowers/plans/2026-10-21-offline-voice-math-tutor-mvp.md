# Offline Voice Math Tutor MVP Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a native macOS app where a learner talks with a local, offline math tutor in English or Mexican Spanish, with natural turn-taking and barge-in.

**Architecture:**
- **Local package `TutorKit`** with three targets:
  - `TutorCore`: pure Swift logic plus the ports (protocols). Unit-tested with `swift test`.
  - `TutorEngines`: adapters for speech-swift, mlx-swift-lm and Phonon. Covered by opt-in integration probes, which double as the de-risking spike.
  - `TutorAudio`: AVAudioEngine I/O with voice processing.
- **The app target** holds the SwiftUI views and a single `AppModel`.
- **Pipeline (cascaded, streaming):**
  1. Mic → Silero VAD → Nemotron streaming ASR and Smart Turn.
  2. Turn end → Qwen token stream → reply parser.
  3. Spoken-math normalizer → Phonon streaming TTS → speaker.

**Tech Stack:**
- Swift with SwiftUI and Swift Testing.
- AVFoundation for audio.
- NaturalLanguage (`NLLanguageRecognizer`) for language detection.
- [soniqo/speech-swift](https://github.com/soniqo/speech-swift) (Apache-2.0): products `SpeechVAD` and `NemotronStreamingASR`.
- [ml-explore/mlx-swift-lm](https://github.com/ml-explore/mlx-swift-lm): products `MLXLLM` and `MLXLMCommon`.
- [gradium-ai/xn-ptts](https://github.com/gradium-ai/xn-ptts): product `ptts`, module `PhononTTS`.

**Spec:** `docs/superpowers/specs/2026-10-21-offline-voice-math-tutor-mvp-design.md`

## Global Constraints

- **Target system:** MacBook Pro, Apple M4 Max, 36 GB, macOS 27.0.1.
  - Keep `MACOSX_DEPLOYMENT_TARGET = 27.0`.
  - Supported platforms: macOS only.
- **Success targets:**
  - Reply latency (turn declared over → first audible TTS sample): ≤ ~1.0 s typical.
  - Barge-in (VAD speech-onset frame → tutor audio ducked): ≤ ~300 ms.
  - A 20-minute session runs with no stutter, no crash and no swap-forcing memory growth.
  - Total app working set stays under ~12 GB.
- **Fully local after the first-run download:**
  - No network calls during a session.
  - No Python, Homebrew, Ollama, LM Studio, external server or external process in the app.
- **Inference stack:** Core ML or MLX only, using Swift and Apple frameworks wherever possible.
- **Licenses:**
  - The app is open source.
  - GPL dependencies are allowed, but the app's license must then be GPL-3.0-compatible.
  - No AGPL.
  - CC BY-NC weights are allowed but must never be committed to the repo.
- **Languages:** English, and Spanish in its **Mexican** variety ("tres punto cinco", "por", Latin American voice).
- **Headphones:** not required. A headphones prompt is only the fallback when voice processing is unavailable or echo leaks.
- **Copy:** the app's text presents it as a general math tutor and never mentions children.
- **Reply format:** the speech text is written for the ear. Expressions go in actions, never spoken literally (no "three slash four", no "x caret two").
- **Out of scope for the MVP:**
  - guardian features, profiles, memory, drawing;
  - a signed or notarized DMG, Sparkle;
  - Apple's built-in models (Foundation Models, SpeechAnalyzer, AVSpeechSynthesizer voices);
  - duplex models;
  - languages other than English and Spanish.

## Review Focus

1. **Qwen emits `<think>…</think>` reasoning.** It must never be spoken or shown. Covered by Task 7 (`dropsThinkBlocks`) and Task 5 (thinking disabled in the chat template).
2. **A tag or sentence boundary split across LLM stream chunks** (`"<sh"` + `"ow>x</show>"`) must parse exactly as if unsplit. Covered by Task 7 (`tagSplitAcrossChunks`).
3. **Short, ambiguous turns** ("sí", "ok", "5") must not flip the reply language. They fall back to the setting. Covered by Task 9 (`shortUtteranceFallsBackToSetting`).
4. **History growth over a 20-minute session** must stay bounded so reply latency and memory don't creep. Covered by Task 12 (`historyIsCappedAtTwelveTurns`).
5. **Typed text sent while the tutor is speaking** is a barge-in: stop, then answer the typed text. Covered by Task 12 (`typedInputWhileSpeakingInterrupts`).

---

## File Structure

```
AgenticTutor.xcodeproj                      (modify: macOS only, link TutorKit, entitlements)
AgenticTutor/
  MyApp.swift                               (modify: inject AppModel)
  ContentView.swift                         (modify: Setup vs Conversation routing)
  AppModel.swift                            (create: @Observable app state, owns engine)
  Views/SetupView.swift                     (create: first-run download/prepare screen)
  Views/ConversationView.swift              (create: state, captions, expression, text field, language)
  Views/TimingPanel.swift                   (create: per-stage latency + memory)
  AgenticTutor.entitlements                 (create/modify: audio-input, network.client)
  PhononModels/                             (generated by script, gitignored, folder reference)
scripts/export-phonon.sh                    (create: dev-only Core ML export of Phonon 40m multilingual)
TutorKit/Package.swift                      (create)
TutorKit/Sources/TutorCore/
  Ports.swift                               (shared types + protocols every target uses)
  ReplyStreamParser.swift                   (LLM token stream → speech segments + actions)
  SpokenMath.swift                          (math symbols → words, en / es-MX)
  LanguagePolicy.swift                      (per-turn reply language)
  TutorPrompt.swift                         (system prompt per language)
  TurnTaker.swift                           (pure turn/barge-in state machine)
  LatencyRecorder.swift                     (per-turn metrics + memory footprint)
  ConversationEngine.swift                  (actor orchestrating the pipeline over ports)
  ChunkAccumulator.swift                    (re-chunk audio to fixed 512-sample frames)
TutorKit/Sources/TutorEngines/
  ModelCatalog.swift                        (model ids, sizes, voices, memory tier)
  SileroVAD+Port.swift, SmartTurn+Port.swift, NemotronTranscriber.swift,
  QwenTutor.swift, PhononSpeaker.swift, ModelInstaller.swift
TutorKit/Sources/TutorAudio/
  AudioIO.swift                             (AVAudioEngine, voice processing, capture, playback, duck)
  EchoSelfTest.swift
TutorKit/Tests/TutorCoreTests/…             (one test file per TutorCore file)
TutorKit/Tests/TutorEnginesTests/…Probe.swift  (integration probes, opt-in)
TutorKit/Tests/Fixtures/tutor-prompts.json  (20 prompts per language)
docs/spike/                                 (asr-script.md, results.md, tutor-responses.md, validation.md)
```

**Commands used throughout:**
- **Core unit tests:** `swift test --package-path TutorKit --filter TutorCoreTests`
- **Integration probes** (need models, Metal): `TEST_RUNNER_TUTOR_INTEGRATION=1 xcodebuild test -scheme TutorKit-Package -destination 'platform=macOS' -only-testing:TutorEnginesTests/<Suite>`
- **App build:** `xcodebuild -project AgenticTutor.xcodeproj -scheme AgenticTutor -destination 'platform=macOS' build`

Probes are gated with `@Suite(.enabled(if: ProcessInfo.processInfo.environment["TUTOR_INTEGRATION"] == "1"))`.

---

### Task 1: Project setup, package skeleton, shared ports

**Files:**
- Modify: `AgenticTutor.xcodeproj/project.pbxproj`. Set `SUPPORTED_PLATFORMS = macosx`, add `TutorKit` as a local package, link `TutorCore`, `TutorEngines` and `TutorAudio` to the app, and set `CODE_SIGN_ENTITLEMENTS`.
- Create: `AgenticTutor/AgenticTutor.entitlements` with `com.apple.security.app-sandbox`, `com.apple.security.device.audio-input` and `com.apple.security.network.client`. Set `INFOPLIST_KEY_NSMicrophoneUsageDescription = "The tutor listens to your voice so you can talk through math out loud. Audio never leaves this Mac."`
- Create: `TutorKit/Package.swift`, `TutorKit/Sources/TutorCore/Ports.swift`, and empty-file placeholders for `TutorEngines` and `TutorAudio`.
- Create: `.gitignore` entries: `AgenticTutor/PhononModels/`, `spike-audio/`, `.build/`.
- Create: `docs/spike/asr-script.md`. It has 10 lines per language, each with math words. Lines 08 to 10 contain a mid-sentence thinking pause of about 1.5 s. Examples: "What is seven times eight", "¿Cuánto es tres cuartos más un medio?", "the hypotenuse of a right… triangle". After this task, the owner records each line (QuickTime or Voice Memos, quiet room, adult voices only) to `spike-audio/{en,es}-NN.m4a`; Tasks 3–4 need them.
- Test: `TutorKit/Tests/TutorCoreTests/PortsTests.swift`

**Interfaces:**
- Produces (all `public`, in `TutorCore/Ports.swift`):
```swift
public enum TutorLanguage: String, Sendable, CaseIterable { case english = "en", spanish = "es" }
extension TutorLanguage { public var asrLocale: String }        // "en-US" / "es-US"
public struct TranscriptUpdate: Sendable, Equatable { public var text: String; public var isFinal: Bool }
public struct ChatTurn: Sendable, Equatable { public enum Role: Sendable { case user, tutor }; public var role: Role; public var text: String }
public enum TutorAction: Sendable, Equatable { case show(String) }
public enum ConversationState: Sendable, Equatable { case idle, listening, thinking, speaking }

public protocol VoiceActivityDetecting: AnyObject {            // 512 samples @ 16 kHz
    func speechProbability(_ chunk: [Float]) -> Float
    func reset()
}
public protocol TurnCompletionJudging: AnyObject {             // turn audio @ 16 kHz, any length
    func completionProbability(turnAudio: [Float]) throws -> Float
}
public protocol StreamingTranscribing: AnyObject {
    func begin(language: TutorLanguage) throws                 // starts a fresh session
    func push(_ chunk: [Float]) throws -> TranscriptUpdate?    // latest partial if text changed
    func finish() throws -> String                             // final text, ends session
}
public protocol TutorGenerating: Sendable {
    func reply(system: String, history: [ChatTurn]) -> AsyncThrowingStream<String, Error>
}
public protocol SpeechSynthesizing: Sendable {                  // 24 kHz mono Float32
    func setLanguage(_ language: TutorLanguage) async throws
    func stream(_ text: String) -> AsyncThrowingStream<[Float], Error>
}
public protocol AudioOutput: AnyObject {
    func enqueue(_ samples24k: [Float])
    func duck()                                                 // volume → 0.15 immediately
    func unduck()
    func stopAll()                                              // clear queue, silence now
    var isPlaying: Bool { get }
    var outputLatency: TimeInterval { get }
}
```

**Package.swift decisions:**
- `// swift-tools-version: 6.0`, `platforms: [.macOS("15.0")]`, `swiftLanguageModes: [.v5]`.
- Dependencies:
  - `speech-swift`: latest release tag, from `gh release list -R soniqo/speech-swift`.
  - `mlx-swift-lm`: **exact the version speech-swift pins** (3.31.4 at the time of writing). A different version will not resolve.
  - `xn-ptts`: latest release tag. Its root `Package.swift` pins the prebuilt framework.
- Targets:
  - `TutorCore`: no dependencies.
  - `TutorEngines`: TutorCore, SpeechVAD, NemotronStreamingASR, MLXLLM, MLXLMCommon, ptts.
  - `TutorAudio`: TutorCore.
- Test targets: `TutorCoreTests` and `TutorEnginesTests`, with `resources: [.copy("../Fixtures")]` on the latter.

- [ ] **Step 1: Write the failing test**
```swift
@Test func localesAndCodes() {
    #expect(TutorLanguage.english.rawValue == "en")
    #expect(TutorLanguage.spanish.asrLocale == "es-US")
    #expect(TutorLanguage.english.asrLocale == "en-US")
}
```
- [ ] **Step 2:** Run `swift test --package-path TutorKit --filter TutorCoreTests`. Expected: FAIL, because `TutorLanguage` is undefined.
- [ ] **Step 3:** Create `Package.swift` and `Ports.swift` as specified.
- [ ] **Step 4:** Run the core tests. Expected: PASS.
- [ ] **Step 5:** Edit the project and entitlements, then run the App build command. Expected: `** BUILD SUCCEEDED **` with all three packages resolved.
- [ ] **Step 6:** Commit with `git commit -m "chore: macOS-only project, TutorKit package and shared ports"`.

---

### Task 2: Phonon TTS adapter + Spanish/English listening probe (spike item 1)

**Files:**
- Create: `scripts/export-phonon.sh`. It requires `HF_TOKEN` (an account that has accepted the phonon-40m-multilingual terms) and `cargo`. It clones xn-ptts at the same tag as the Swift package, then runs its `export_coreml` example with `--features hub` and `--model hf://gradium/phonon-40m-multilingual`, writing to `AgenticTutor/PhononModels/`. The script exits non-zero with a clear message if `HF_TOKEN` is missing.
- Modify: the Xcode project. Add `AgenticTutor/PhononModels` as a **folder reference** in Copy Bundle Resources.
- Create: `TutorKit/Sources/TutorEngines/PhononSpeaker.swift`, `TutorKit/Sources/TutorEngines/ModelCatalog.swift`
- Test: `TutorKit/Tests/TutorEnginesTests/PhononProbe.swift`

**Interfaces:**
- Consumes: `SpeechSynthesizing`, `TutorLanguage` (Task 1).
- Produces:
```swift
public final class PhononSpeaker: SpeechSynthesizing {
    public static func load(bundledModels: URL) async throws -> PhononSpeaker   // PhononModels.install(bundled:) then Phonon.load
    public static let sampleRate: Double = 24_000
}
public enum ModelCatalog {
    public static var phononVoiceEnglish: String       // chosen in Step 4
    public static var phononVoiceSpanish: String       // Latin American voice, chosen in Step 4
}
```
- `setLanguage(_:)` calls Phonon's `setLanguage(.english/.spanish)` and `setVoice(…)` only when the language actually changes.
- `stream(_:)` wraps `Phonon.stream(_:)`. Cancelling the consuming task must stop generation, so the wrapper forwards `onTermination` to cancel its producer task.

- [ ] **Step 1:** Run `HF_TOKEN=… scripts/export-phonon.sh`. Expected: `AgenticTutor/PhononModels/bundle.json` exists, and `git status` does not show the folder.
- [ ] **Step 2: Write the probe**
  - `@Test func spanishAndEnglishSamples()` loads `PhononSpeaker` from the exported folder (path via env `PHONON_MODELS`).
  - For every voice in the model's `voices` list that is tagged `es` or `en`, it synthesizes the fixed sentences below to `spike-audio/phonon-<voice>.wav`.
  - It records time-to-first-chunk and real-time factor into `docs/spike/results.md`.
  - It asserts that the first chunk arrives in < 0.2 s.
  - Sentences (exact):
    - EN: "Let's think about three quarters. If you cut a pizza into four equal slices and eat three, how many slices are left?"
    - ES: "Pensemos en tres cuartos. Si cortas una pizza en cuatro rebanadas iguales y te comes tres, ¿cuántas rebanadas quedan? Tres punto cinco es lo mismo que tres y medio."
- [ ] **Step 3:** Run the probe (`-only-testing:TutorEnginesTests/PhononProbe`). Expected: PASS, with WAVs written. Generate the same sentences with Kokoro-82M via the mlx-audio CLI. This is dev-only, purely for comparison, and never part of the app.
- [ ] **Step 4: Owner listening gate.**
  - The owner picks the Latin American Spanish voice and the English voice, and decides Phonon vs Kokoro.
  - Record the decision and voice names in `docs/spike/results.md`, and set them in `ModelCatalog`.
  - If Kokoro wins, stop and revise this task before continuing.
- [ ] **Step 5:** Commit with `git commit -m "feat: Phonon TTS adapter and listening probe"`. Commit only the scripts, code and docs; never the audio or models.

---

### Task 3: Silero VAD + Smart Turn adapters

**Files:**
- Create: `TutorKit/Sources/TutorEngines/SileroVAD+Port.swift`, `TutorKit/Sources/TutorEngines/SmartTurn+Port.swift`
- Test: `TutorKit/Tests/TutorEnginesTests/ListeningProbe.swift`

**Interfaces:**
- Consumes: `VoiceActivityDetecting`, `TurnCompletionJudging` (Task 1).
- Produces:
```swift
public final class SileroVAD: VoiceActivityDetecting {
    public static func load() async throws -> SileroVAD          // SileroVADModel.fromPretrained(engine: .coreml)
}
public final class SmartTurnJudge: TurnCompletionJudging {
    public static func load() async throws -> SmartTurnJudge     // SmartTurnModel.fromPretrained(), then prewarm()
}
```
- `SmartTurnJudge` passes `sampleRate: 16_000` and relies on the model's own last-8-second window.

- [ ] **Step 1: Write the probe**
  - `@Test func vadSeparatesSpeechFromSilence()`: 1 s of zeros gives a max probability < 0.2. `spike-audio/en-01.*` resampled to 16 kHz gives at least 10 chunks > 0.5.
  - `@Test func smartTurnSeparatesCompleteFromCutOff()`: the full `en-01` clip is > 0.5. The same clip cut at 40 % of its length is < 0.5 (log both). Also log the timing of one inference.
- [ ] **Step 2:** Run it. Expected: FAIL to compile, because the types don't exist yet.
- [ ] **Step 3:** Implement both adapters.
- [ ] **Step 4:** Run it. Expected: PASS. Append the timings to `docs/spike/results.md`.
- [ ] **Step 5:** Commit with `git commit -m "feat: Silero VAD and Smart Turn adapters"`.

---

### Task 4: Nemotron streaming ASR adapter + accuracy probe (spike item 2)

**Files:**
- Create: `TutorKit/Sources/TutorEngines/NemotronTranscriber.swift`
- Test: `TutorKit/Tests/TutorEnginesTests/NemotronProbe.swift`

**Interfaces:**
- Consumes: `StreamingTranscribing`, `TutorLanguage.asrLocale` (Task 1).
- Produces:
```swift
public final class NemotronTranscriber: StreamingTranscribing {
    public static func load() async throws -> NemotronTranscriber   // NemotronStreamingASRModel.fromPretrained() (Core ML INT8 default), warmUp()
    public static let mathVocabulary: [TutorLanguage: [String]]     // ≥ 25 terms each: numerator, denominator, hypotenuse, fraction, decimal, times, divided by… / numerador, denominador, hipotenusa, fracción, punto, por, entre, al cuadrado…
}
```
- `begin(language:)` calls `createSession(language: language.asrLocale, wordBoosting: WordBoostingConfig(phrases from mathVocabulary, boosts from model.wordBoostingSuggestions))`.
- If `es-MX` is in the model's languages, prefer it over `es-US`. Implement this as `asrLocale(for:)` checking `NemotronLanguages`.

- [ ] **Step 1: Write the probe**
  - `@Test func transcribesOwnerRecordings()` streams each `spike-audio/*` file in 512-sample chunks through `push`, then `finish`.
  - It computes word error rate against the script, ignoring case and punctuation.
  - It writes a per-line table to `docs/spike/results.md`.
  - Asserts:
    - mean WER < 0.15 per language;
    - every math term in the script appears in at least 80 % of the lines that contain it.
- [ ] **Step 2:** Run it. Expected: FAIL to compile.
- [ ] **Step 3:** Implement. Run it. Expected: PASS. If WER ≥ 0.15 for Spanish, record that and flag it for the Task 6 gate, where the Parakeet v3 fallback is decided.
- [ ] **Step 4:** Commit with `git commit -m "feat: Nemotron streaming transcriber with math word boosting"`.

---

### Task 5: Tutor prompt + Qwen adapter + tutoring probe (spike item 3)

**Files:**
- Create: `TutorKit/Sources/TutorCore/TutorPrompt.swift`, `TutorKit/Sources/TutorEngines/QwenTutor.swift`, `TutorKit/Tests/Fixtures/tutor-prompts.json`
- Test: `TutorKit/Tests/TutorCoreTests/TutorPromptTests.swift`, `TutorKit/Tests/TutorEnginesTests/QwenProbe.swift`

**Interfaces:**
- Consumes: `TutorGenerating`, `ChatTurn`, `TutorLanguage` (Task 1).
- Produces:
```swift
public enum TutorPrompt { public static func system(for language: TutorLanguage) -> String }
public final class QwenTutor: TutorGenerating {
    public static func load(modelId: String) async throws -> QwenTutor   // loadModelContainer(id:)
}
extension ModelCatalog {
    public static let tutorModelId = "mlx-community/Qwen3.5-4B-4bit"
    public static func tutorModelId(physicalMemory: UInt64) -> String   // returns tutorModelId for every tier until Task 6 sets a ≥32 GB pick
}
```

**System prompt content** (the builder writes the wording; all of these are required):
- One idea per turn, at most 3 short sentences.
- Ask a guiding question rather than giving answers, and check understanding.
- Elementary to early-middle-school level.
- Reply only in the given language.
- No markdown and no emoji.
- Write numbers and symbols **as words** in speech.
- Put any expression the learner should see inside `<show>…</show>` and refer to it in words.
- Spanish only: Mexican conventions. Decimals are "punto", multiplication is "por", division is "entre".

**QwenTutor rules:**
- `reply` builds `[system] + history` messages.
- Pass `["enable_thinking": false]` as additional chat-template context.
- Use temperature 0.6 and maxTokens 300.
- Stream with the message-array `streamResponse`.
- Cancelling the consumer cancels generation.

**`tutor-prompts.json`:** `{"en": [20 strings], "es": [20 strings]}`. Cover arithmetic, place value, fractions and decimals, basic geometry and area, and simple patterns and functions. Include 3 deliberately wrong learner answers per language, such as "I think 1/2 + 1/3 is 2/5".

- [ ] **Step 1: Write the failing tests**
```swift
@Test func spanishPromptUsesMexicanConventions() {
    let p = TutorPrompt.system(for: .spanish)
    #expect(p.contains("<show>") && p.contains("punto") && p.contains("por"))
}
@Test func promptsDemandShortSpokenTurns() {
    for l in TutorLanguage.allCases { #expect(TutorPrompt.system(for: l).contains("<show>")) }
    #expect(!TutorPrompt.system(for: .english).localizedCaseInsensitiveContains("child"))
}
```
- [ ] **Step 2:** Run the core tests. Expected: FAIL.
- [ ] **Step 3:** Implement `TutorPrompt`. Run the core tests. Expected: PASS.
- [ ] **Step 4: Write the probe**
  - `@Test func answersPromptSet()` runs all 40 prompts as single-turn conversations.
  - It writes each prompt and reply to `docs/spike/tutor-responses.md`.
  - It records time to first token and tokens/s.
  - Asserts:
    - no reply contains `<think>`;
    - median time to first token < 0.5 s;
    - Spanish replies are detected as Spanish by `NLLanguageRecognizer`.
- [ ] **Step 5:** Implement `QwenTutor`. Run the probe. Expected: PASS.
- [ ] **Step 6:** **Owner review gate.** The owner reads `tutor-responses.md` for correctness and teaching style. Record the verdict in `results.md`. Prompt wording may be revised and re-run here.
- [ ] **Step 7:** Commit with `git commit -m "feat: tutor prompt and Qwen MLX adapter"`.

---

### Task 6: Spike gate: all models together (spike items 4–5)

**Files:**
- Test: `TutorKit/Tests/TutorEnginesTests/StackMemoryProbe.swift`
- Modify: `docs/spike/results.md`, `ModelCatalog.swift`, and the spec's "Calls made" if any fallback is taken.

**Interfaces:**
- Consumes: the `load()` functions from Tasks 2–5.
- Produces: `public func currentFootprintBytes() -> UInt64` in `TutorCore/LatencyRecorder.swift`, using `task_vm_info.phys_footprint`. Task 11 reuses it.

- [ ] **Step 1: Write the probe**
  - `@Test func wholeStackFitsBudget()` loads all five engines.
  - It runs one pass: ASR on `en-01`, then a Qwen reply, then a Phonon synthesis.
  - It asserts that peak `currentFootprintBytes()` is < 12 GB.
  - It logs the footprint after each load.
- [ ] **Step 2:** Run it. Expected: PASS. If it fails, record the numbers and stop for an owner decision.
- [ ] **Step 3:** Decide the ≥ 32 GB tier.
  - If footprint with the next larger Qwen3.5 4-bit MLX model stays < 12 GB and its time to first token is < 0.5 s, set it in `tutorModelId(physicalMemory:)` for ≥ 32 GiB.
  - Otherwise keep 4B. Record the decision.
- [ ] **Step 4:** Summarize the spike in `results.md`:
  - each spike item, pass or fail;
  - the fallbacks taken (Parakeet, Kokoro, Gemma 3n);
  - the voices chosen.

  Note that echo leakage (item 5) is measured in Task 13.
- [ ] **Step 5:** Commit with `git commit -m "test: whole-stack memory probe and spike results"`.

---

### Task 7: ReplyStreamParser

**Files:**
- Create: `TutorKit/Sources/TutorCore/ReplyStreamParser.swift`
- Test: `TutorKit/Tests/TutorCoreTests/ReplyStreamParserTests.swift`

**Interfaces:**
- Produces:
```swift
public enum ReplyPiece: Sendable, Equatable { case speech(String), action(TutorAction) }
public struct ReplyStreamParser {
    public init(minPhraseCharacters: Int = 24)
    public mutating func feed(_ chunk: String) -> [ReplyPiece]
    public mutating func finish() -> [ReplyPiece]
}
```

**Rules:**
- Text inside `<show>…</show>` becomes `.action(.show(trimmed))` and is removed from speech.
- `<think>…</think>` is dropped entirely.
- An opening `<show>` flushes any pending speech first, regardless of `minPhraseCharacters`, so order is preserved.
- Speech is emitted at a phrase boundary (`. ? ! ; :` or newline) once the buffer has at least `minPhraseCharacters`, or at `finish()`.
- Speech is whitespace-collapsed and never empty.
- An unterminated tag is held until it closes or `finish()`. At `finish()`, an unclosed `<show>` becomes an action and an unclosed `<think>` is dropped.

- [ ] **Step 1: Write the failing tests**
```swift
@Test func splitsSpeechAndActions() {
    var p = ReplyStreamParser(minPhraseCharacters: 1)
    let out = p.feed("Look at this. <show>3/4 + 1/4</show> What do you get?") + p.finish()
    #expect(out == [.speech("Look at this."), .action(.show("3/4 + 1/4")), .speech("What do you get?")])
}
@Test func tagSplitAcrossChunks() {
    var p = ReplyStreamParser(minPhraseCharacters: 1)
    let out = ["Try <sh", "ow>x²", "</sho", "w> now."].flatMap { p.feed($0) } + p.finish()
    #expect(out == [.speech("Try"), .action(.show("x²")), .speech("now.")])
}
@Test func dropsThinkBlocks() {
    var p = ReplyStreamParser(minPhraseCharacters: 1)
    let out = p.feed("<think>secret</think>Hello there.") + p.finish()
    #expect(out == [.speech("Hello there.")])
}
@Test func waitsForMinimumPhraseLength() {
    var p = ReplyStreamParser(minPhraseCharacters: 24)
    #expect(p.feed("Yes. ") == [])
    #expect(p.feed("Now multiply both sides by two.") == [.speech("Yes. Now multiply both sides by two.")])
}
```
- [ ] **Step 2:** Run the core tests. Expected: FAIL.
- [ ] **Step 3:** Implement it as a character-level state machine (text / inShow / inThink / pendingTag buffer).
- [ ] **Step 4:** Run the core tests. Expected: PASS.
- [ ] **Step 5:** Commit with `git commit -m "feat: streaming reply parser for speech and show actions"`.

---

### Task 8: SpokenMath normalizer

**Files:**
- Create: `TutorKit/Sources/TutorCore/SpokenMath.swift`
- Test: `TutorKit/Tests/TutorCoreTests/SpokenMathTests.swift`

**Interfaces:**
- Produces: `public enum SpokenMath { public static func speakable(_ text: String, language: TutorLanguage) -> String }`

**Rules:**
- Only rewrite math tokens. Plain integers are left for Phonon's own normalizer.
- **Fractions** `a/b` with integer parts:
  - Denominators 2–10 use their names:
    - EN: half/halves, third(s), quarter(s), fifth(s)…tenth(s);
    - ES: medio(s), tercio(s), cuarto(s), quinto(s), sexto(s), séptimo(s), octavo(s), noveno(s), décimo(s).
  - Other denominators: EN "a over b", ES "a sobre b".
- **Powers:** `²`/`^2` → "squared"/"al cuadrado"; `³`/`^3` → "cubed"/"al cubo"; `^n` → "to the power of n"/"a la n".
- **Operators:**
  - `×`/`*` → "times"/"por";
  - `÷` → "divided by"/"entre";
  - `=` → "equals"/"es igual a";
  - `+` → "plus"/"más";
  - `−` and `-` between operands → "minus"/"menos";
  - `%` → "percent"/"por ciento";
  - `√x` → "the square root of x"/"la raíz cuadrada de x".
- **Decimals:** `3.5` → "3 point 5"/"3 punto 5".

- [ ] **Step 1: Write the failing tests**
```swift
@Test(arguments: [
    ("3/4 of the pizza", TutorLanguage.english, "three quarters of the pizza"),
    ("1/2", .english, "one half"),
    ("3/4", .spanish, "tres cuartos"),
    ("5/12", .spanish, "5 sobre 12"),
    ("x² + 1 = 10", .english, "x squared plus 1 equals 10"),
    ("x^3", .spanish, "x al cubo"),
    ("3.5 × 2", .spanish, "3 punto 5 por 2"),
    ("8 ÷ 2 - 1", .english, "8 divided by 2 minus 1"),
    ("50%", .spanish, "50 por ciento"),
    ("√9", .english, "the square root of 9"),
    ("Great job!", .english, "Great job!"),
])
func speakable(_ input: String, _ lang: TutorLanguage, _ expected: String) {
    #expect(SpokenMath.speakable(input, language: lang) == expected)
}
```
Numerators 1–10 are spelled out in named fractions ("three quarters", "tres cuartos"). Elsewhere, integers stay as digits.
- [ ] **Step 2:** Run the core tests. Expected: FAIL.
- [ ] **Step 3:** Implement with ordered regex passes: fractions, then powers, then decimals, then operators.
- [ ] **Step 4:** Run the core tests. Expected: PASS.
- [ ] **Step 5:** Commit with `git commit -m "feat: spoken math normalizer for English and Mexican Spanish"`.

---

### Task 9: LanguagePolicy

**Files:**
- Create: `TutorKit/Sources/TutorCore/LanguagePolicy.swift`
- Test: `TutorKit/Tests/TutorCoreTests/LanguagePolicyTests.swift`

**Interfaces:**
- Produces: `public enum LanguagePolicy { public static func replyLanguage(for transcript: String, setting: TutorLanguage) -> TutorLanguage }`

**Rules:**
- Use `NLLanguageRecognizer` with `languageConstraints = [.english, .spanish]`.
- Return the top language only if its probability is ≥ 0.80 **and** the transcript has ≥ 3 words.
- Otherwise return `setting`. That covers short and mixed turns.

- [ ] **Step 1: Write the failing tests**
```swift
@Test func detectsSpanish() { #expect(LanguagePolicy.replyLanguage(for: "¿cuánto es siete por ocho, maestro?", setting: .english) == .spanish) }
@Test func detectsEnglish() { #expect(LanguagePolicy.replyLanguage(for: "what is seven times eight please", setting: .spanish) == .english) }
@Test func shortUtteranceFallsBackToSetting() {
    #expect(LanguagePolicy.replyLanguage(for: "sí", setting: .english) == .english)
    #expect(LanguagePolicy.replyLanguage(for: "5", setting: .spanish) == .spanish)
}
@Test func mixedTurnFallsBackToSetting() { #expect(LanguagePolicy.replyLanguage(for: "is it tres cuartos or not", setting: .spanish) == .spanish) }
```
- [ ] **Step 2:** Run the tests. Expected: FAIL. **Step 3:** Implement. **Step 4:** Run the tests. Expected: PASS.
- [ ] **Step 5:** Commit with `git commit -m "feat: per-turn reply language policy"`.

---

### Task 10: TurnTaker state machine

**Files:**
- Create: `TutorKit/Sources/TutorCore/TurnTaker.swift`
- Test: `TutorKit/Tests/TutorCoreTests/TurnTakerTests.swift`

**Interfaces:**
- Produces:
```swift
public struct TurnConfig: Sendable {
    public var vadThreshold: Float = 0.5
    public var onsetChunks = 2                     // 2 × 32 ms above threshold = speech onset
    public var pauseTrigger: TimeInterval = 0.40   // silence before asking Smart Turn
    public var recheckInterval: TimeInterval = 0.12
    public var completeThreshold: Float = 0.6
    public var confirmCount = 2                    // consecutive "complete" verdicts
    public var silenceFallback: TimeInterval = 3.0 // end turn regardless of Smart Turn
    public var bargeInConfirm: TimeInterval = 0.384
    public var bargeInRelease: TimeInterval = 0.30
    public init()
}
public enum TurnInput: Sendable { case vad(Float, at: TimeInterval), verdict(Float, at: TimeInterval),
    asrWords(at: TimeInterval), hold(Bool, at: TimeInterval), tutorSpeaking(Bool) }
public enum TurnEndReason: Sendable, Equatable { case smartTurn, silenceFallback }
public enum TurnOutput: Sendable, Equatable { case userSpeechStarted(at: TimeInterval), checkTurn(at: TimeInterval),
    turnEnded(at: TimeInterval, reason: TurnEndReason, silenceAllowance: TimeInterval),
    duckTutor(at: TimeInterval), bargeIn(at: TimeInterval), unduckTutor(at: TimeInterval) }
public struct TurnTaker { public init(config: TurnConfig = .init()); public mutating func process(_ input: TurnInput) -> [TurnOutput] }
```

**Semantics:**
- `.userSpeechStarted` fires at the onset chunk time. The ASR begins there.
- While the user is silent for ≥ `pauseTrigger`, emit `.checkTurn` every `recheckInterval`.
- `confirmCount` consecutive verdicts ≥ `completeThreshold` emit `.turnEnded(.smartTurn)`. `silenceAllowance` is the time from the last speech chunk to the end.
- Any speech resets the verdict count.
- Silence ≥ `silenceFallback` ends the turn with `.silenceFallback`.
- **Hold:**
  - While held, no `.checkTurn` and no `.turnEnded`.
  - On release, silence timing restarts from the release time.
- **While the tutor is speaking:**
  - Onset emits `.duckTutor` (not `.userSpeechStarted`).
  - Speech lasting ≥ `bargeInConfirm` since onset, **or** `.asrWords`, emits `.bargeIn` then `.userSpeechStarted(at: onset)`.
  - Silence ≥ `bargeInRelease` before confirmation emits `.unduckTutor`.

- [ ] **Step 1: Write the failing tests.** Use a helper `feed(_ probs: [Float], from t0: TimeInterval)` that steps 0.032 s per chunk.
  - `onsetAfterTwoSpeechChunks`: `[0.9, 0.9]` from t = 0 → `.userSpeechStarted(at: 0.0)`.
  - `pauseTriggersCheckAfter400ms`: speech, then silence; the first `.checkTurn` is at ≥ 0.40 s of silence, then every 0.12 s.
  - `twoCompleteVerdictsEndTurn`: verdicts 0.7, 0.7 → `.turnEnded(reason: .smartTurn)`. Verdicts 0.7, 0.3, 0.7 → no end.
  - `holdSuppressesTurnEnd`: hold(true), then 5 s of silence → no `.checkTurn` and no `.turnEnded`. Release, then 3.0 s → `.turnEnded(.silenceFallback)`.
  - `silenceFallbackAfter3s`: speech, then 3.0 s of silence with all verdicts 0.1 → `.silenceFallback`.
  - `bargeInDucksThenConfirms`: tutorSpeaking(true); speech from t = 1.0 → `.duckTutor(at: 1.032)` within the first 2 chunks; `.bargeIn` at ≤ t + 0.384 + 0.032.
  - `bargeInConfirmsEarlyOnASRWords`: duck, then `.asrWords` → `.bargeIn` immediately.
  - `coughIsReleased`: tutorSpeaking(true); 3 speech chunks, then silence → `.duckTutor` then `.unduckTutor`, and no `.bargeIn`.
- [ ] **Step 2:** Run the tests. Expected: FAIL. **Step 3:** Implement. **Step 4:** Run the tests. Expected: PASS.
- [ ] **Step 5:** Commit with `git commit -m "feat: turn-taking and barge-in state machine"`.

---

### Task 11: LatencyRecorder

**Files:**
- Create: `TutorKit/Sources/TutorCore/LatencyRecorder.swift` (it already holds `currentFootprintBytes()` from Task 6)
- Test: `TutorKit/Tests/TutorCoreTests/LatencyRecorderTests.swift`

**Interfaces:**
- Produces:
```swift
public struct TurnMetrics: Sendable, Equatable {
    public var silenceAllowance: TimeInterval?, asrFinalize: TimeInterval?, llmFirstToken: TimeInterval?,
               ttsFirstAudio: TimeInterval?, replyLatency: TimeInterval?, bargeInDuck: TimeInterval?, footprintBytes: UInt64
}
public struct LatencyRecorder {
    public enum Mark: Sendable { case speechOnset, turnEnded(silenceAllowance: TimeInterval), asrFinal, llmFirstToken, ttsFirstChunk, firstEnqueue(outputLatency: TimeInterval), duck }
    public init()
    public mutating func mark(_ m: Mark, at t: TimeInterval)
    public mutating func close(footprint: UInt64) -> TurnMetrics     // resets for the next turn
}
```

**Definitions:**
- `replyLatency` = firstEnqueue + outputLatency − turnEnded.
- `asrFinalize`, `llmFirstToken` and `ttsFirstAudio` are each measured from the previous stage mark.
- `bargeInDuck` = duck − speechOnset.

- [ ] **Step 1: Write the failing test**
  - `computesReplyLatency`: marks at turnEnded(silenceAllowance: 0.5) @ 10.0, asrFinal @ 10.05, llmFirstToken @ 10.35, ttsFirstChunk @ 10.40, firstEnqueue(outputLatency: 0.02) @ 10.41.
  - Expect `replyLatency ≈ 0.43`, `asrFinalize ≈ 0.05`, `llmFirstToken ≈ 0.30`, `ttsFirstAudio ≈ 0.05`, and `silenceAllowance == 0.5`.
  - `bargeInDuck`: onset @ 5.0, duck @ 5.07 → 0.07.
- [ ] **Step 2:** Run the tests. Expected: FAIL. **Step 3:** Implement. **Step 4:** Run the tests. Expected: PASS.
- [ ] **Step 5:** Commit with `git commit -m "feat: per-turn latency recorder"`.

---

### Task 12: ConversationEngine

**Files:**
- Create: `TutorKit/Sources/TutorCore/ConversationEngine.swift`, `TutorKit/Sources/TutorCore/ChunkAccumulator.swift`
- Test: `TutorKit/Tests/TutorCoreTests/ConversationEngineTests.swift` (fakes for every port in `TutorKit/Tests/TutorCoreTests/Fakes.swift`), `ChunkAccumulatorTests.swift`

**Interfaces:**
- Consumes: all ports (Task 1), `ReplyStreamParser` (7), `SpokenMath` (8), `LanguagePolicy` (9), `TurnTaker` (10), `TutorPrompt` (5), `LatencyRecorder`, `TurnMetrics` (11).
- Produces:
```swift
public struct ChunkAccumulator { public init(size: Int = 512); public mutating func append(_ s: [Float]) -> [[Float]] }
public enum ConversationEvent: Sendable, Equatable {
    case state(ConversationState), userCaption(String, isFinal: Bool), tutorCaption(String),
         action(TutorAction), metrics(TurnMetrics), error(String) }
public actor ConversationEngine {
    public init(vad: VoiceActivityDetecting, judge: TurnCompletionJudging, asr: StreamingTranscribing,
                tutor: TutorGenerating, tts: SpeechSynthesizing, output: AudioOutput,
                setting: TutorLanguage, config: TurnConfig = .init(), mergeWindow: TimeInterval = 2.0,
                maxHistoryTurns: Int = 12, now: @escaping @Sendable () -> TimeInterval)
    public nonisolated var events: AsyncStream<ConversationEvent> { get }
    public func start(); public func stop()
    public func ingest(micChunk16k: [Float], at time: TimeInterval)   // exactly 512 samples
    public func setHold(_ held: Bool, at time: TimeInterval)
    public func submitTyped(_ text: String)
    public func setLanguageSetting(_ language: TutorLanguage)
}
```

**Behavior:**
- **Ingest:** VAD → `TurnTaker`. While the user is speaking, push chunks to the ASR and emit `.userCaption` partials.
  - Keep turn audio from onset for Smart Turn.
  - On `.checkTurn`, call `judge` and feed the verdict back.
- **On `.turnEnded`:**
  1. `asr.finish()`.
  2. `LanguagePolicy` decides the reply language.
  3. Append the user `ChatTurn`.
  4. Start the reply task: `tutor.reply(system: TutorPrompt.system(for:), history: last maxHistoryTurns)` → parser.
  5. Each `.speech` piece goes through `SpokenMath.speakable`, then `tts.setLanguage` (only on change), then `tts.stream`, then `output.enqueue`. Synthesis is sequential, in order.
  6. Each `.action` piece is emitted as an event.
  7. State goes thinking → speaking (at the first enqueue) → listening (once the reply is done and `!output.isPlaying`).
  8. Commit the tutor `ChatTurn` with the speech text that was enqueued.
- **Duck / unduck / bargeIn:**
  - `.duckTutor` → `output.duck()`; `.unduckTutor` → `output.unduck()`.
  - `.bargeIn` → `output.stopAll()`, cancel the reply task, commit only the speech already enqueued, and start a new user turn.
- **Early-cutoff merge:** if a confirmed user onset happens < `mergeWindow` after the previous `.turnEnded`:
  - drop the tutor turn for that reply (do not commit it);
  - remove the previous user turn from history;
  - when the new turn ends, send `previousUserText + " " + newText` as one user turn.
- **`submitTyped`:** if speaking or thinking, behave like `.bargeIn` (no merge), then treat the text as a finished user turn.
- **Errors** from any port emit `.error(message)` and return to listening. They never crash or stop the session.

- [ ] **Step 1: Write the failing tests** with fakes.
  - Fakes are scripted:
    - VAD probabilities from an array;
    - the judge returns a fixed value;
    - the ASR returns fixed text;
    - the tutor yields given chunks with an optional delay and records cancellation;
    - TTS yields one `[Float](repeating: 0, count: 2400)` per call and records its texts and languages;
    - output records calls.
  - Tests:
    - `endToEndReplySpeaksNormalizedPhrases`: tutor chunks `["Look: <show>3/4</show> ", "That is 3/4 of it."]` → TTS texts `["Look:", "That is three quarters of it."]`; events include `.action(.show("3/4"))`; states go listening → thinking → speaking → listening.
    - `bargeInStopsAndCancels`: during speaking, sustained speech → `output.duck` then `output.stopAll`, the tutor fake records cancellation, and the history's last tutor turn contains only the enqueued text.
    - `earlyCutoffMergesTurns`: user "what is seven", turn ends, the user speaks again 1.0 s later saying "times eight" → the last history passed to the tutor has one user turn, "what is seven times eight", and no tutor turn between.
    - `typedInputWhileSpeakingInterrupts`: during speaking, `submitTyped("and 9 times 9?")` → `stopAll` is called and the next tutor call's last user turn is "and 9 times 9?".
    - `historyIsCappedAtTwelveTurns`: after 10 exchanges, the tutor fake receives ≤ 12 history turns.
    - `spanishTurnSwitchesVoice`: ASR text "¿cuánto es siete por ocho, maestro?" with setting `.english` → `tts.setLanguage(.spanish)` before the first stream.
    - `portErrorReturnsToListening`: the tutor throws → `.error` event, then `.state(.listening)`.
  - `ChunkAccumulatorTests`: appending 300 and then 300 samples yields one chunk of 512, with 88 carried over.
- [ ] **Step 2:** Run the core tests. Expected: FAIL.
- [ ] **Step 3:** Implement.
- [ ] **Step 4:** Run the core tests. Expected: PASS, including all earlier suites.
- [ ] **Step 5:** Commit with `git commit -m "feat: conversation engine with barge-in, early-cutoff merge and typed input"`.

---

### Task 13: AudioIO with voice processing + echo self-test (spike item 5)

**Files:**
- Create: `TutorKit/Sources/TutorAudio/AudioIO.swift`, `TutorKit/Sources/TutorAudio/EchoSelfTest.swift`
- Test: `TutorKit/Tests/TutorEnginesTests/AudioProbe.swift`. It is manual and gated, because it needs the mic and speakers.

**Interfaces:**
- Consumes: `AudioOutput`, `ChunkAccumulator`, `VoiceActivityDetecting`.
- Produces:
```swift
public final class AudioIO: AudioOutput {
    public init() throws                            // throws AudioIOError.voiceProcessingUnavailable if setVoiceProcessingEnabled(true) fails
    public var onMicChunk: ((_ chunk16k: [Float], _ time: TimeInterval) -> Void)?   // 512 samples, time = ProcessInfo.systemUptime at capture
    public func start() throws; public func stop()
}
public enum EchoSelfTest {
    /// Plays `probe` (24 kHz) and counts VAD chunks above 0.5 while it plays; leaks if count ≥ 3.
    public static func run(io: AudioIO, vad: VoiceActivityDetecting, probe: [Float]) async -> Bool   // true = leaks
}
```

**AudioIO internals:**
- One `AVAudioEngine`; call `inputNode.setVoiceProcessingEnabled(true)` before `start()`.
- An input tap converts with `AVAudioConverter` to 16 kHz mono Float32, then `ChunkAccumulator(512)`.
- An `AVAudioPlayerNode` at 24 kHz mono goes through `mainMixerNode`.
- `duck()` sets the player volume to 0.15; `stopAll()` calls `player.stop()` then `play()`.
- `outputLatency` = `outputNode.presentationLatency`.

- [ ] **Step 1:** Write the probe `@Test func echoLeakageOnBuiltInSpeakers()`:
  - It synthesizes "This is a short echo test. One, two, three." with `PhononSpeaker`.
  - It runs `EchoSelfTest` on the built-in speakers, with no headphones.
  - It logs the VAD count and asserts `leaks == false`.
  - It also measures `duck()` → volume change at ≤ 10 ms.
- [ ] **Step 2:** Implement `AudioIO` and `EchoSelfTest`.
- [ ] **Step 3:** Run the probe on the target system in a quiet room. Expected: PASS. Record the count in `docs/spike/results.md` (spike item 5). If it leaks, the headphones fallback in Task 15 becomes the default path. Record that.
- [ ] **Step 4:** Commit with `git commit -m "feat: audio I/O with voice processing and echo self-test"`.

---

### Task 14: ModelInstaller (first-run download, offline afterwards)

**Files:**
- Create: `TutorKit/Sources/TutorEngines/ModelInstaller.swift`
- Test: `TutorKit/Tests/TutorEnginesTests/InstallerProbe.swift`

**Interfaces:**
- Consumes: the `load` functions from Tasks 2–5, and `ModelCatalog`.
- Produces:
```swift
public struct LoadedEngines { public let vad: SileroVAD; public let judge: SmartTurnJudge; public let asr: NemotronTranscriber; public let tutor: QwenTutor; public let tts: PhononSpeaker }
public struct InstallStep: Sendable { public let title: String; public let approxBytes: Int64 }
public enum ModelInstaller {
    public static var steps: [InstallStep] { get }   // Voice detection ~2 MB, Turn detection ~8 MB, Speech recognition ~612 MB, Tutor ~2.5 GB, Voice ~75 MB (prepare/compile)
    public static var isInstalled: Bool { get }       // marker file in Application Support/AgenticTutor/installed.json
    public static func loadAll(bundledPhonon: URL, progress: @escaping @Sendable (_ fraction: Double, _ title: String) -> Void) async throws -> LoadedEngines
}
```

**Rules:**
- Overall progress is weighted by `approxBytes`.
- Write the marker only after every load succeeds.
- When the marker exists, load from local caches with no network. If `fromPretrained` contacts the network even when cached, switch to speech-swift's `fromLocal`/`fromDirectory` and mlx-swift-lm's local-directory configuration for installed models.

- [ ] **Step 1:** Write the probe `@Test func secondLoadWorksOffline()`. It calls `loadAll` twice and asserts that the second call takes < 30 s and that `isInstalled` is true.
- [ ] **Step 2:** Implement it. Run the probe. Expected: PASS.
- [ ] **Step 3: Manual offline check.**
  1. Turn Wi-Fi off.
  2. Run the probe's second half.
  3. Expected: PASS with no URL errors in the log.
- [ ] **Step 4:** Commit with `git commit -m "feat: model installer with offline reload"`.

---

### Task 15: App UI and wiring

**Files:**
- Create: `AgenticTutor/AppModel.swift`, `AgenticTutor/Views/SetupView.swift`, `AgenticTutor/Views/ConversationView.swift`, `AgenticTutor/Views/TimingPanel.swift`
- Modify: `AgenticTutor/MyApp.swift`, `AgenticTutor/ContentView.swift`

**Interfaces:**
- Consumes: `ModelInstaller.loadAll` / `steps` / `isInstalled` (14), `AudioIO` + `EchoSelfTest` (13), `ConversationEngine` + `ConversationEvent` (12), `TurnMetrics` (11), `TutorLanguage` (1).
- Produces: `@Observable @MainActor final class AppModel`, with:
  - `phase: Phase` (`.setup(progress: Double, title: String)`, `.ready`, `.failed(String)`);
  - `state: ConversationState`;
  - `userCaption: String`, `tutorCaption: String`, `expression: String?`;
  - `language: TutorLanguage` (persisted in `@AppStorage("language")`, default `.english`);
  - `lastMetrics: TurnMetrics?`;
  - `needsHeadphones: Bool`;
  - `start()`, `stop()`, `send(_ text: String)`, `setHold(_:)`.

**Behavior:**
- **Launch:** if `!ModelInstaller.isInstalled`, show `SetupView`. It lists each `InstallStep` title with its size, shows an overall progress bar, and says "Everything runs on this Mac. After this download, the tutor works offline."
- **Microphone permission:** request `AVCaptureDevice.requestAccess(for: .audio)` before `start()`. If denied, show "Microphone access is off. Turn it on in System Settings › Privacy & Security › Microphone." with a button opening that pane. The app must not crash.
- **First `start()` per launch:**
  - Run `EchoSelfTest` with a fixed Phonon probe phrase.
  - If it leaks, or `AudioIO` threw `voiceProcessingUnavailable`, set `needsHeadphones` and show the one-line banner "For best results, please use headphones." The conversation still starts.
- **`ConversationView`:**
  - start/stop button;
  - a state indicator (Listening / Thinking / Speaking, or "Escuchando / Pensando / Hablando" when the setting is Spanish);
  - captions for both sides;
  - the latest `expression`, monospaced and large;
  - a `TextField` that submits to `send`;
  - a language `Picker` (English / Español).
- **Spacebar:** `.onKeyPress(.space, phases: [.down, .up])` calls `setHold(true/false)` when the text field is **not** focused. Show "Take your time…" while held.
- **`TimingPanel`** (toggle with ⌘⇧T):
  - the last turn's `silenceAllowance`, `asrFinalize`, `llmFirstToken`, `ttsFirstAudio`, `replyLatency` and `bargeInDuck` in ms;
  - the footprint in GB, shown red when > 12 GB, with `replyLatency` red when > 1.0 s and `bargeInDuck` red when > 0.3 s.
- No copy anywhere mentions children.

- [ ] **Step 1:** Implement `AppModel`, wiring `AudioIO.onMicChunk` → `engine.ingest` and `engine.events` → published properties.
- [ ] **Step 2:** Implement the views.
- [ ] **Step 3:** Run the App build command. Expected: `** BUILD SUCCEEDED **`.
- [ ] **Step 4: Manual smoke test** on the target system. Each of these is expected to work:
  - The first launch shows setup and completes.
  - Asking "what is three quarters plus one quarter" gets a spoken reply and shows an expression.
  - Talking over the tutor stops it.
  - Holding the space bar through a 3 s pause does not end the turn.
  - Switching to Spanish mid-session and asking in Spanish gets a Spanish voice.
  - Typing a question while the tutor speaks interrupts it.
  - Denying the mic shows the message.
- [ ] **Step 5:** Commit with `git commit -m "feat: SwiftUI app with setup, conversation and timing panel"`.

---

### Task 16: Validation run against the success criteria

**Files:**
- Create: `docs/spike/validation.md`

- [ ] **Step 1:** On the target system, with Wi-Fi **off**, the built-in speakers and no headphones, run one 20-minute session, ten or more minutes in each language. Use prompts from `tutor-prompts.json`, include at least 10 deliberate interruptions and at least 5 held-spacebar pauses, and export the timing panel's per-turn metrics to CSV (add a "Copy metrics" button to `TimingPanel` if needed).
- [ ] **Step 2:** Record the following in `validation.md`:
  - the median and p90 of `replyLatency` (target ≤ ~1.0 s typical);
  - the median and p90 of `bargeInDuck` (target ≤ ~300 ms);
  - peak footprint (target < 12 GB) and any stutter or crash;
  - the owner's verdict on correctness and teaching style in both languages.
- [ ] **Step 3:** If any target is missed, list the stage responsible, using the metrics breakdown, and propose a tuning change. Do not tune silently.
- [ ] **Step 4:** Commit with `git commit -m "docs: MVP validation results"`.
