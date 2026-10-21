# Task 2 implementation report

## Implemented

- Added `scripts/export-phonon.sh`, which requires `HF_TOKEN`, clones `xn-ptts` tag `v0.4.0` into a temporary directory, and runs the verified positional-output `export_coreml` command into `AgenticTutor/PhononModels/`.
- Added `PhononSpeaker`, including bundle installation/loading, language-to-catalog voice selection, explicit probe voice selection, 24 kHz sample-rate exposure, and an `AsyncThrowingStream` wrapper that cancels its producer on termination.
- Added documented, listening-gate placeholder `ModelCatalog` voice variables.
- Added the English/Spanish Phonon probe. It resolves the exported model directory from `PHONON_MODELS`, auditions every `en`/`es` tagged voice, writes Float32 WAVs under `spike-audio/`, records first-chunk latency and real-time factor in `docs/spike/results.md`, and asserts first chunks arrive within 0.2 seconds.
- Added the ignored `AgenticTutor/PhononModels` folder reference to Copy Bundle Resources and removed the always-passing engine placeholder test.

## Verification

Passed:

```sh
bash -n scripts/export-phonon.sh
swiftc -parse TutorKit/Sources/TutorEngines/ModelCatalog.swift TutorKit/Sources/TutorEngines/PhononSpeaker.swift TutorKit/Tests/TutorEnginesTests/PhononProbe.swift
swiftc -typecheck ... PhononSpeaker.swift ModelCatalog.swift
swiftc -typecheck ... PhononProbe.swift
plutil -lint AgenticTutor.xcodeproj/project.pbxproj
git diff --check
```

The two type checks used the existing Xcode DerivedData `PhononTTS` and `TutorCore` modules plus the Testing macro plugin; both completed successfully. The Xcode project lint reported `OK`.

Not run, by task scope:

- The model export needs the owner's `HF_TOKEN` and network access.
- The Phonon probe needs the exported model bundle and is reserved for the controller's listening/comparison steps.
- `xcodebuild` was not run. A `swift build --package-path TutorKit --target TutorEngines` attempt was blocked before compilation by the sandbox's SwiftPM/Clang cache restrictions.

## Files changed

- `scripts/export-phonon.sh`
- `AgenticTutor.xcodeproj/project.pbxproj`
- `TutorKit/Sources/TutorEngines/ModelCatalog.swift`
- `TutorKit/Sources/TutorEngines/PhononSpeaker.swift`
- `TutorKit/Tests/TutorEnginesTests/PhononProbe.swift`
- `TutorKit/Tests/TutorEnginesTests/PlaceholderTests.swift` (removed)

## Self-review

- Confirmed the exporter command matches the pinned v0.4.0 source: its output is positional rather than `--out`.
- Confirmed the first normal language selection applies the catalog voice; subsequent identical language selections perform no Phonon language or voice call.
- Confirmed the probe's sentences exactly match the brief and it writes standard 24 kHz mono Float32 WAV files.
- Confirmed no model bundle or generated audio was staged.

## Concern

The placeholders in `ModelCatalog` deliberately remain unusable until the owner listening gate selects and records the English and Mexican Spanish voices.

## Commit

- `d4c76c0 feat: Phonon TTS adapter and listening probe`

## Fix round 1

### Implemented

- Refused exports when `AgenticTutor` or `AgenticTutor/PhononModels` is a symlink, then resolved the output directory and verified that it remains inside the repository before any model writes.
- Added optional space-separated `PHONON_VOICE_IDS`; each validated ID downloads its voice file into the temporary workspace and supplies that directory with `--voices` to the pinned exporter.

### Verification

Passed:

```sh
bash -n scripts/export-phonon.sh
```

`shellcheck` was not available in the environment. The export was not run, per task scope.

### Files changed

- `scripts/export-phonon.sh`
- `.superpowers/sdd/2026-10-21-offline-voice-math-tutor-mvp/task-2-report.md`

### Self-review

- The token is only passed in curl's authorization request header; the script neither enables tracing nor logs the header.
- Voice IDs are restricted to alphanumerics, underscores, and hyphens before being used in paths or URLs.
