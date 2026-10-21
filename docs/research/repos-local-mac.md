# Open-source local voice assistants and demos (Apple Silicon focus)

Research snapshot: 2026-10-21. Stars, license, and last-push dates come from the GitHub API on that date. Items marked "snippet only" come from search summaries, not from reading the repo.

## Summary table

| Project | Stars | License | Last push | Language | Mac runtime | Pipeline | UI | Mac status |
|---|---|---|---|---|---|---|---|---|
| [huggingface/speech-to-speech](https://github.com/huggingface/speech-to-speech) | 13.5k | Apache-2.0 | 2026-10-21 | Python | MLX (LLM via mlx-lm, STT via Parakeet MLX, TTS via mlx-audio) | Cascade: Silero VAD, Parakeet TDT, Qwen3.5-4B, Qwen3-TTS | CLI (`speech-to-speech local`), OpenAI Realtime WebSocket/WebRTC server | First-class. Official Mac config (`example_configs/mac.yaml`) and CI smoke test on Apple Silicon |
| [Blaizzy/mlx-audio](https://github.com/Blaizzy/mlx-audio) | 8.1k | MIT | 2026-10-21 | Python (+ Swift package) | MLX | Library, not an assistant: TTS, STT, STS, VAD, diarization | CLI, Python API, web UI, OpenAI-compatible server | Native. Used as the Mac TTS/STT backend inside speech-to-speech |
| [kyutai-labs/moshi](https://github.com/kyutai-labs/moshi) | 11.3k | Apache-2.0 | 2026-09-09 | Python (`moshi_mlx`), Rust, PyTorch | MLX (`moshi_mlx`), PyTorch (CUDA only), Rust/Candle | End-to-end full-duplex speech-text model (no separate STT/LLM/TTS) | CLI and `moshi_mlx.local_web` browser UI | Supported on Mac via MLX. Several open Mac bug reports |
| [kyutai-labs/unmute](https://github.com/kyutai-labs/unmute) | 1.5k | MIT | 2026-09-09 | Python + Rust services | None. Docker/CUDA on x86_64 Linux | Cascade: Kyutai STT, any text LLM, Kyutai TTS | Web frontend (unmute.sh) | Not supported. Maintainers say "currently no" on Mac |
| [dnhkng/GLaDOS](https://github.com/dnhkng/GLaDOS) | 5.8k | MIT | 2026-10-11 | Python | llama.cpp (Metal or CUDA), ONNX speech models | VAD over 32 ms chunks with 416 ms silence gap, Parakeet or Gemma 4 audio input, Gemma 4 E4B via separate llama-server, ONNX TTS | Browser web console, local mic, animated avatar | Experimental. README says macOS support "remains experimental" |
| [vndee/local-talking-llm](https://github.com/vndee/local-talking-llm) | 896 | MIT | 2026-04-04 | Python | Ollama, Whisper, Coqui-style TTS (not MLX-native) | Whisper STT, Ollama LLM, TTS | CLI | Runs on Mac, but last push is 6+ months old |
| [mezbaul-h/june](https://github.com/mezbaul-h/june) | 788 | MIT | 2024-08-12 | Python | Ollama, Hugging Face Transformers, Coqui TTS | Whisper STT, Ollama LLM, Coqui TTS | CLI | Stale (last push over 2 years ago). Note: I could not resolve `nlpodyssey/june`; this is the June voice assistant that exists |
| [apeatling/ollama-voice-mac](https://github.com/apeatling/ollama-voice-mac) | 519 | AGPL-3.0 | 2025-08-21 | Python | Ollama (Mistral 7B), Whisper, macOS system voices | Simple STT-LLM-TTS loop | CLI | Stale; AGPL is a poor fit for a closed product |
| [huwprosser/jarvis-mlx](https://github.com/huwprosser/jarvis-mlx) | 521 | none listed | 2026-05-11 | Python | MLX (MeloTTS for speech) | Assistant, offline on MacBook (per repo description) | Not verified | Metadata only; README not read |
| [ddalcu/mlx-serve](https://github.com/ddalcu/mlx-serve) | 2.0k | "Other" | 2026-10-21 | Zig backend, Swift macOS app | Native Zig inference for Apple Silicon (MLX use not verified) | Inference server, not a voice loop (voice cloning only) | Menu-bar macOS app, OpenAI/Anthropic/Ollama-compatible API | Active. Useful as a native-app reference, not a voice assistant |
| [Beingpax/VoiceInk](https://github.com/Beingpax/VoiceInk) | 6.9k | "Other" | 2026-10-21 | Swift | Local Whisper/Parakeet | Dictation (not a conversational assistant) | Native macOS app | Reference for native UX, distribution, and hotkeys |
| [kitlangton/Hex](https://github.com/kitlangton/Hex) | 2.9k | MIT | archived | Swift | WhisperKit | Dictation | Native macOS | Archived. Successor is at a different repo |

Other repos I checked (not in the table):
- `pipecat-ai/pipecat` (16.7k stars, BSD-2) and `livekit/agents` (14.9k, Apache-2.0). These are frameworks for building voice agents, not end-user apps. Both support Mac-local models, but most of their examples target cloud APIs.
- `kyutai-labs/delayed-streams-modeling` (3.0k, Apache-2.0). Kyutai's standalone STT/TTS. Its README says it can run on Apple Silicon via MLX. Last push 2026-01-26.
- `ml-explore/mlx-swift-examples` (2.7k, MIT). Swift MLX example apps, useful as a reference for a native LLM path.
- `argmaxinc/WhisperKit` (6.4k, MIT). On-device Whisper on Apple Silicon via Core ML.
- `ollama/ollama` (184k, MIT) and `ollama/ollama-python` (10.6k, MIT). Mature local LLM server and Python client.

Snippet-only findings (not verified against repos): FluidAudio (Swift SDK for ANE-based ASR/TTS/VAD), Voxing (MLX terminal voice assistant), Hitoku Draft (Show HN, local macOS assistant), Frog (macOS companion using llama.cpp and FluidAudio), LocalTalk (Whisper, gpt-oss on MLX, ChatterBox), and `eauchs/speech-to-speech-pipeline` (Apple Silicon Python script with barge-in, Faster Whisper, MLX Kokoro).

---

## Per-project notes

### 1. huggingface/speech-to-speech (closest prior art)

- **Repo:** https://github.com/huggingface/speech-to-speech. Apache-2.0, Python, 13.5k stars, pushed 2026-10-21. Trending #1 on GitHub at some point.
- **Models (Apple Silicon default):**
  - VAD: Silero VAD v5.
  - STT: Parakeet TDT 0.6B via MLX. Other options include Whisper via mlx-audio and Lightning Whisper MLX.
  - LLM: Qwen3.5-4B 4-bit (`mlx-community/Qwen3.5-4B-4bit`) via mlx-lm. The README's hardware table says plan for 16 GB unified memory.
  - TTS: Qwen3-TTS (1.7B CustomVoice by default) via mlx-audio. Kokoro-82M and others are optional.
- **Mac runtime:** MLX throughout. `--mac-optimal-settings` sets MPS as default for supported components. All three models run through MLX on macOS.
- **Latency and memory:**
  - The README gives no benchmark table for Mac hardware.
  - Its example log line (`stt=0.18s llm=1.24s tts_ttfa=0.12s e2e=2.01s`) has no stated hardware.
  - Budget: "24 GB of unified memory on Mac" for the default speech models, with about 8 GB for the speech pipeline. The Mac hardware table says 16 GB. These conflict, so treat 24 GB as the safer number.
  - The project has a `docs/response-latency.md` that defines per-stage metrics and emits them as JSON in `response.done` metadata. This is a model for instrumenting our own app.
- **VAD, turn-taking, interruption:**
  - Silero VAD v5 for speech boundaries.
  - Optional Smart Turn v3.2 (ONNX, CPU) for semantic end-of-turn. A 600 ms "incomplete" delay and 2 s max wait are configurable.
  - Interruption via `interrupt_response: true` in the Realtime `server_vad` config.
  - Echo: no acoustic echo cancellation. README says "use headphones, or add `--local_audio_block_mic_during_playback`."
- **Installation:** `pip install speech-to-speech` then `speech-to-speech local`. Requires CPython 3.11–3.14 (3.11 recommended). First run downloads several GB of models. Needs system libraries on Linux (portaudio). Python 3.15 not yet supported.
  - For a non-developer, this is a Terminal-and-Python install. Not acceptable as the product install, but fine as a dev path.
- **UI:** CLI (`local` with a colored transcript), and `serve` for an OpenAI Realtime API WebSocket/WebRTC server. Any Realtime client can connect, including the OpenAI Agents SDK.
- **Design decisions worth noting:**
  - The pipeline is four threads connected by queues. Each stage is swappable by config.
  - A YAML config ("named pipelines", environment references) and a plugin/tool-calling module (`--tool-module`).
  - The OpenAI Realtime protocol is the public boundary. This lets any app reuse the backend.
  - An MLX lock serializes Metal work across STT/TTS/LLM. Its contention is logged as `mlx_lock_wait`. Relevant if we run several models on one GPU.
- **Pain points from issues (open and recent):**
  - #738 (closed): the default CLI output mixed backend logs, protocol events, and duplicate transcripts, making normal conversation hard to follow. Fixed by making clean output the default.
  - #724 (open): a retry immediately after `response.cancel` can complete with no output after a tool call.
  - #745 (open): Phonon TTS does not record end-to-end latency.
  - #716 (open): a large proposal to make the pipeline a streaming DAG. Shows the cascade is getting more complex over time.

### 2. Blaizzy/mlx-audio (building block, not an assistant)

- **Repo:** https://github.com/Blaizzy/mlx-audio. MIT, Python, 8.1k stars, pushed 2026-10-21. Pip package `mlx-audio`.
- **What it provides:** TTS (Kokoro, Qwen3-TTS, Chatterbox, VoxCPM2, Voxtral TTS, MeloTTS, and many more), STT (Voxtral Realtime, Nemotron streaming ASR, VibeVoice-ASR, Whisper), VAD (Silero via MLX), diarization, STS, and music generation.
- **Interfaces:** CLI (`mlx_audio.tts.generate`, with `--stream` and `--play`), Python API, a web UI with 3D audio visualization, an OpenAI-compatible REST server, and a Swift package for iOS/macOS.
- **Voice-chat demo:** The README does not include a full voice-conversation loop. The conversation loop lives in speech-to-speech, which uses mlx-audio as its Qwen3-TTS and Whisper backend.
- **Latency/RAM:** Not reported in the README.
- **Install:** `pip install mlx-audio`. Developers only. Models are downloaded from `mlx-community` on Hugging Face.
- **Takeaway:** Good to know about for TTS choice (Kokoro 82M is small and fast). Not a product by itself.

### 3. kyutai-labs/moshi (full-duplex, MLX implementation)

- **Repo:** https://github.com/kyutai-labs/moshi. Apache-2.0, 11.3k stars, last push 2026-09-09.
- **Architecture:** Speech-to-speech as one model. Moshi (7B temporal transformer plus depth transformer) predicts two audio streams (user and itself) plus an inner-monologue text stream. Mimi is a 12.5 Hz streaming codec. The README claims 160 ms theoretical latency and "as low as 200 ms on an L4 GPU." The Mac numbers are not reported.
- **Mac runtime:** `moshi_mlx` (MLX) with int4, int8, or bf16 weights (`kyutai/moshiko-mlx-q4`, `-q8`, `-bf16`). Run with `python -m moshi_mlx.local -q 4` or `python -m moshi_mlx.local_web`. The README says the MLX version was tested on a MacBook Pro M3. The PyTorch version needs about 24 GB of GPU memory and has no quantization.
- **VAD and turn-taking:** Not needed. Full-duplex: the model listens and speaks at once and handles interruption natively. This is the main difference from the cascade designs.
- **Installation:** `pip install -U moshi_mlx` (best with Python 3.12). Rust toolchain needed if the wheel build fails (`rustymimi`). Developer-level install.
- **UI:** CLI and a local web UI. The hosted demo at moshi.chat uses a separate client.
- **Pain points from issues:**
  - #421 (open): MLX q4 and q8 lag and high latency on an M4 MacBook Pro, with heating.
  - #289 (open): the MLX server crashes after about 2 minutes with "narrow invalid args" errors in the encoder thread (M2 Pro, q4).
  - #141 (open): through Pinokio on an M2 Air, the model listens about 15 seconds and then quits.
  - #186 (open): Rust Metal features do not work on Mac.
  - #290 (open): the web UI for the 4b MLX model does not load.
- **Takeaway:** Full-duplex is the most natural conversation feel, but the open-source Mac path is buggy and only one model family (Moshi) is available. Not a safe MVP base. Watch it as a future option.

### 4. kyutai-labs/unmute (cascade, GPU-only)

- **Repo:** https://github.com/kyutai-labs/unmute. MIT, 1.5k stars, last push 2026-09-09. Python and Rust services.
- **Pipeline:** Kyutai STT (streaming), any text LLM (production uses GPT-OSS 120B via OpenRouter; local default is Gemma 3 1B), and Kyutai TTS. It uses websockets from browser to backend, then to STT, LLM, and TTS servers.
- **Mac support:** Not supported. The README says "Neither is running on Mac (see #74)." Issue #74 is closed, and the maintainer answered "currently no." Their reasons: the TTS needed 8-bit quantization to run in real time on a Mac, vLLM does not support Mac GPUs, and an MLX STT server would need to be written.
- **Hardware:** Docker Compose on x86_64 with a CUDA GPU of at least 16 GB VRAM. ARM is not planned.
- **UI:** Web frontend (`unmute.sh`) with a connect button. Good reference for the UX of "click to connect, talk, interrupt."
- **Takeaway:** Good architecture reference (the STT → LLM → TTS streaming flow and interruption handling). Not runnable on a MacBook.

### 5. dnhkng/GLaDOS (persona voice assistant, experimental Mac)

- **Repo:** https://github.com/dnhkng/GLaDOS. MIT, 5.8k stars, pushed 2026-10-11. Python.
- **Features:** Voice conversation, a GLaDOS voice and animated browser avatar, persistent memory, vision (camera observations through Gemma 4 E4B), MCP tools, and "cores" (emotion, memory, vision, system health, research) feeding a shared context.
- **Models:** Gemma 4 E4B via a separate llama.cpp `llama-server` (Q4_0 GGUF, about 4.6 GB). Speech: ONNX models downloaded by `glados download`. Parakeet is an alternative STT. A direct-audio mode uses Gemma 4's audio input.
- **Mac runtime:** llama.cpp (Metal supported in principle). The README says macOS support "remains experimental" and the reference setup is CUDA. Known issues on Mac, mostly closed: "No audio output on Mac" (#91), Metal shader header error (#79), and missing `llama-server` path (#80).
- **VAD and turn-taking:** 32 ms VAD chunks, a 416 ms silence gap completes a turn, and a resumed utterance cancels the pending response. Interruption stops playback when the `interruptible` setting is on. Echo: headphones recommended. The docs say to disable `interruptible` if playback re-triggers the mic.
- **Latency and RAM:** Documented in `docs/gemma4.md` and `docs/benchmarks` (not read in detail). The README says latency depends on hardware and enabled cores.
- **Installation:** `git clone` then `python scripts/install.py` (Python 3.12+). Requires separately installing `llama-server` and downloading GGUF files manually. Not a non-developer install.
- **UI:** Browser console at `127.0.0.1:8050` with mic and voice controls, a live view of each core, memory, and tasks. The most product-like UI among the Python projects.
- **Takeaway:** A strong reference for personality, persistent memory, and the UX of a visible "mind" panel. Its installation is not suited to non-developers, and Mac support is not a first-class target.

### 6. Older or stale Python projects (short notes)

- **vndee/local-talking-llm** (896 stars, MIT, last push 2026-04-04). Whisper, Ollama, and a TTS engine in Python, CLI. Works on Mac but has not been maintained for 6+ months. Good reference for the simplest viable loop.
- **mezbaul-h/june** (788 stars, MIT, last push 2024-08-12). Local voice chatbot with Ollama, Hugging Face Transformers, and Coqui TTS. A third-party write-up reports the mic did not detect silence in a noisy office and memory use was high on a 12 GB machine. I could not find `nlpodyssey/june`; this is the June project that exists.
- **apeatling/ollama-voice-mac** (519 stars, AGPL-3.0, last push 2025-08-21). Mistral 7B via Ollama, Whisper, and macOS system voices. Shows the "Mac voices as TTS" shortcut, which is low quality but zero-install. AGPL means we should not reuse code.
- **huwprosser/jarvis-mlx** (521 stars, no license listed, last push 2026-05-11). MLX assistant with MeloTTS. No license means we cannot reuse code.

### 7. Native Swift and SwiftUI macOS apps

Native apps that do voice conversation are rare. The building blocks are good.

- **WhisperKit** (argmaxinc/argmax-oss-swift, 6.4k stars, MIT, pushed 2026-10-11). On-device Whisper via Core ML and the Neural Engine. Swift package. Homebrew formula `whisperkit-cli` at 0.9.4.
- **FluidAudio** (FluidInference/FluidAudio, snippet only). Swift SDK for ANE-based ASR (Parakeet TDT, Parakeet EOU for streaming), TTS (Kokoro, PocketTTS), VAD, diarization, and end-of-utterance detection. Supports macOS 14+ and Swift 6. The `FluidAudioTTS` product includes ESpeakNG under GPL-3.0, which matters for a closed-source app. Check the current version before depending on it.
- **mlx-swift-examples** (ml-explore/mlx-swift-examples, 2.7k stars, MIT). Example MLX LLM apps in Swift. Good reference for running an LLM natively, without Python.
- **VoiceInk** (Beingpax/VoiceInk, 6.9k stars, pushed 2026-10-21, license "Other"). Native macOS dictation app with a polished UI, hotkeys, and local Whisper or Parakeet. Not a conversational assistant, but the best native-Mac UX reference I found. Check the license before reuse.
- **Hex** (kitlangton/Hex, MIT, 2.9k stars, archived). WhisperKit-based dictation. Archived; its successor lives at another repo.
- **mlx-serve** (ddalcu/mlx-serve, 2.0k stars, pushed 2026-10-21, license "Other"). Zig inference server with a Swift menu-bar macOS app. Useful reference for packaging a native Mac app around a local model.
- **Hitoku Draft** (Show HN, snippet only). Open-source voice-first macOS assistant. Hotkey to talk. Gemma 4 via LiteRT, Qwen 3.5 via MLX. The author reports memory spikes and hallucination on long contexts.
- **Frog** (snippet only). Open-source macOS companion. Hotkey dictation, llama.cpp with Gemma, and Qwen2.5 for lower-RAM Macs. Uses Apple SpeechAnalyzer or Parakeet through FluidAudio.

I could not find an open-source native SwiftUI app that does a full voice-to-voice loop with WhisperKit and Ollama. The Ollama-based voice app that does exist (ollama-voice-mac) is Python. This is a gap, and the accessibility-focused macOS app we are planning could fill it.

---

## Comparison notes

**End-to-end latency numbers reported:**

| Project | Reported | Hardware |
|---|---|---|
| speech-to-speech | Example log: stt 0.18 s, llm 1.24 s, TTS first audio 0.12 s, e2e 2.01 s | Not stated |
| Moshi | Theoretical 160 ms, practical ~200 ms | NVIDIA L4 (PyTorch, not Mac) |
| Moshi MLX on Mac | Not reported; issue #421 reports lag on M4 | M4 MacBook Pro |
| GLaDOS | Not in README; `docs/gemma4.md` has measured results | CUDA reference setup |
| Unmute | Not reported for Mac | N/A |

**RAM reported:**
- speech-to-speech: 16 GB unified memory (Mac hardware table), 24 GB (budget text). About 8 GB goes to speech models.
- Moshi PyTorch: 24 GB GPU (no quantization). MLX q4 and q8 sizes are not stated in the README.
- GLaDOS: Gemma 4 E4B Q4_0 is about 4.6 GB on disk. Full RAM not in README.

**Installation difficulty for non-developers:**
- speech-to-speech: `pip` install plus Python version constraints. Models download at first run. Hard.
- Moshi MLX: `pip` plus possible Rust toolchain. Hard.
- Unmute: Docker and NVIDIA. Not applicable.
- GLaDOS: git clone, installer script, separate `llama-server` build, manual GGUF downloads. Hard.
- ollama-voice-mac and local-talking-llm: Ollama app plus Python. Medium, but unmaintained.
- Native Swift apps (VoiceInk, Hex): `.dmg` or App Store style. Easy for the user, but none combine assistant and voice loop.

**Recurring issues across projects:**
- Acoustic echo: every project relies on headphones or disables interruption. None ship echo cancellation as a default.
- Silence detection in noisy rooms: reported by june and implied by GLaDOS's silence-gap tuning.
- Sustained-load crashes and heat: Moshi MLX reports crashes and heating after minutes of use.
- Long-context memory use and hallucination: reported for Hitoku Draft.
- Mac support as an afterthought: Unmute refuses Mac, GLaDOS is experimental on Mac, and Moshi's Mac bugs stay open.

---

## Takeaways for our MVP

1. **Use a cascade (VAD → STT → LLM → TTS), not full-duplex.** Speech-to-speech, GLaDOS, and Unmute all use it, and it lets each stage be swapped and debugged. Moshi's Mac path is still buggy (#289, #421, #141). Keep full-duplex as a later option.

2. **Start with Silero VAD and a fixed silence gap, then add an optional smarter endpoint model.** GLaDOS uses 32 ms chunks with a 416 ms gap. Speech-to-speech adds Smart Turn v3.2 with a 600 ms hold. Ship the fixed-gap version first, and add the semantic model only if turn-taking is poor in testing.

3. **Plan for echo from day one.** Every reference project tells users to wear headphones. A non-developer will not read that. Either detect and mute the mic during playback (speech-to-speech's `--local_audio_block_mic_during_playback`), or use Apple's voice-processing audio unit for echo cancellation (this is my suggestion, not tested in these repos). Make "interrupt the tutor" a setting, and disable it when the echo test fails.

4. **Use Apple Silicon-native runtimes in the app.** MLX (via mlx-audio, mlx-swift, or mlx-lm), WhisperKit or FluidAudio for STT/VAD in Swift. Speech-to-speech, mlx-audio, and Moshi are Python and would need to be bundled, which hurts distribution. Confirm that the Swift path covers the TTS voice quality we need before committing.

5. **Size the default model tier to a 16 GB Mac and show the user.** Speech-to-speech budgets 24 GB for its default models; Qwen3.5-4B 4-bit plus speech models fits 16 GB only narrowly. Default to the smallest model that gives acceptable tutoring quality, then offer a larger tier only on machines that report enough memory. Test on a base 16 GB machine.

6. **Build the installer as a signed `.dmg` that downloads models with visible progress.** The "`pip install` then `speech-to-speech local`" path, and GLaDOS's manual GGUF step, are not usable for our target users. Models are several GB; first-run download needs a progress bar, resumable downloads, and a clear "ready" state (speech-to-speech's `Loading models…` / `Ready — start speaking.` is a good example of the status text).

7. **Keep the pipeline behind small interfaces and emit per-stage latency.** Speech-to-speech's stage timings (`stt`, `llm`, `tts_ttfa`, `e2e`) are a good model for a hidden debug panel. This gives us a measurable target for the "feels responsive" goal and helps diagnose the sustained-load issues others hit.

8. **Check licenses before reusing any code.** Several projects are unsafe for a closed-source product: ollama-voice-mac (AGPL-3.0), FluidAudio's TTS product (ESpeakNG GPL-3.0), and jarvis-mlx (no license). Apache-2.0 (speech-to-speech, Moshi) and MIT (mlx-audio, WhisperKit, Unmute, GLaDOS) are safe to depend on.

9. **Test long sessions before calling the MVP done.** Moshi MLX crashes after about 2 minutes (#289) and heats up (#421). Build a 30-minute soak test with a fixed script and watch memory, thermal state, and latency drift.

10. **Make the "talk to the tutor" entry point a single big button, with a hotkey, not an always-on mic by default.** VoiceInk and Hitoku Draft use hotkeys; Unmute uses a connect button. Push-to-talk avoids VAD false triggers in noisy rooms (reported for june), which matter more for non-developers than hands-free purity.
