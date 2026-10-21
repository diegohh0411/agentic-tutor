# Open-source real-time voice agent frameworks: prior art

Research snapshot: 2026-10-21. Star counts, license and last-push dates come from `gh repo view` on that date. Architecture and feature claims come from README and docs pages fetched in the same session, plus search-result summaries where noted. Items marked **(unverified)** come from third-party summaries or memory and were not confirmed against primary sources. Nothing was cloned or run.

## Summary table

| Project | Repo | Stars | License | Lang | Last push | Pipeline | Apple Silicon / local |
|---|---|---|---|---|---|---|---|
| Pipecat | pipecat-ai/pipecat | 16,693 | BSD-2-Clause | Python | 2026-10-21 | Cascaded + S2S, frame pipeline | Via community example (kwindla) and Local transport; no first-party MLX |
| LiveKit Agents | livekit/agents | 14,881 | Apache-2.0 | Python (+JS) | 2026-10-21 | Cascaded + realtime models | Not a local-first design; console mode for local audio I/O |
| TEN Framework | TEN-framework/ten-framework | 11,186 | Apache-2.0 "with additional restrictions" | Python agents, Go API server, Node/pnpm frontend | 2026-10-21 | Cascaded + S2S, extension graph | Docker-based; no Apple Silicon guidance |
| Hugging Face speech-to-speech | huggingface/speech-to-speech | 13,514 | Apache-2.0 | Python | 2026-10-21 | Cascaded (VAD→STT→LLM→TTS), threaded queues | Yes: MLX for LLM, TTS, STT on macOS |
| RealtimeSTT | KoljaB/RealtimeSTT | 10,200 | MIT | Python | 2026-10-18 | STT library | macOS: PortAudio only; CPU path on Apple Silicon not documented |
| RealtimeTTS | KoljaB/RealtimeTTS | 4,043 | MIT | Python | 2026-10-19 | TTS library | Yes: CPU wheels for Apple Silicon macOS 11+; Metal out of scope |
| RealtimeVoiceChat | KoljaB/RealtimeVoiceChat | 3,860 | Not detected by GitHub; README says MIT | Python + JS | 2025-07-11 | Cascaded, WebSocket | CUDA-first; author says no longer maintained |
| Vocode | vocodedev/vocode-core | 3,806 | MIT | Python | 2024-11-15 | Cascaded (transcriber / agent / synthesizer) | Not documented; stale |
| Smart Turn (Pipecat) | pipecat-ai/smart-turn | 1,630 | BSD-2-Clause | Python | 2026-01-29 | Turn-detection model | ONNX, CPU-friendly (int8 ~8 MB) |
| kwindla/macos-local-voice-agents | kwindla/macos-local-voice-agents | 341 | None listed | Python + JS | 2025-08-26 | Pipecat example, fully local on macOS | Yes (MLX Whisper, mlx-audio Kokoro, LM Studio LLM) |
| eauchs/speech-to-speech-pipeline | eauchs/speech-to-speech-pipeline | 10 | MIT | Python | 2026-10-07 | Local cascaded, barge-in | Yes (MLX, Kokoro, LM Studio or Ollama) |

Related: mlx-audio (Blaizzy/mlx-audio, 8,082 stars, MIT, pushed 2026-10-21) is the MLX TTS/STT/STS library that several of these local examples depend on. pipecat-ai/pipecat-examples (399 stars, BSD-2-Clause, pushed 2026-10-20) holds official example apps.

---

## 1. Pipecat (pipecat-ai/pipecat)

- **Repo / stats:** https://github.com/pipecat-ai/pipecat. 16,693 stars, about 2.9k forks, BSD-2-Clause, Python, not archived, pushed 2026-10-21. Maintained by Daily plus the community. Minimum Python 3.11, 3.12+ recommended.
- **Architecture:** Composable pipelines built from processors. The README says "Each pipeline is an agent" and supports handoffs, parallel fan-out, sidecar workers, and distributed deployment. The frame-based internals (FrameProcessor / Pipeline / PipelineTask, frame types such as InterruptionFrame) are **(unverified this session; from memory)**. The docs page I tried for interruptions returned 404.
- **Speech-to-speech vs cascaded:** Both. Cascaded STT→LLM→TTS is the main path. Speech-to-speech services are listed (OpenAI Realtime, Gemini Multimodal Live, AWS Nova Sonic).
- **Transports:** Daily (WebRTC), LiveKit (WebRTC), SmallWebRTCTransport (serverless local WebRTC, used by kwindla's example), Vonage, FastAPI WebSocket, WebSocket server, WhatsApp, and a `local` transport (needs system deps via the `local` extra). Telephony serializers: Twilio, Plivo, Telnyx, Vonage, Exotel, Genesys.
- **Streaming strategy:** LLM tokens stream into a sentence aggregator that feeds TTS **(sentence-chunking is standard in Pipecat; details unverified this session)**. Services and transports are interchangeable through the pipeline.
- **VAD and end-of-turn:** Silero VAD is the base. Smart Turn (below) is the end-of-turn model. Pipecat docs say `TurnAnalyzerUserTurnStopStrategy` with `LocalSmartTurnAnalyzerV3` became the default user-turn stop strategy as of v0.0.102, and that Smart Turn works best with a short VAD `stop_secs` (0.2 s recommended, also the default). Source: search summary of docs.pipecat.ai (not fetched directly).
- **Interruption handling:** Configured through `interruption_strategies` in `PipelineParams` (for example `MinWordsInterruptionStrategy`, min_words=3 in the example). Strategies run in list order, and the first match interrupts. A separate `MinWordsUserTurnStartStrategy` exists for turn start, and its word threshold applies only while the bot is speaking. Source: search summary of docs.pipecat.ai.
- **Echo cancellation:** Not covered in the README. It is left to the transport or the client. Pipecat's own issue tracker has no echo-specific thread found in this pass.
- **Latency numbers:** None first-party in the README. Third-party benchmarks disagree. A VAmoS study reports Pipecat median latency of 1.95 s with 17 barge-ins per 100 calls, versus 7 for LiveKit **(third-party, unverified)**. A Cekura vendor benchmark reports about 3.15 s for Pipecat, with the highest interruption score (4.90) **(vendor, unverified)**.
- **Local / Apple Silicon:** The README does not mention MLX or Apple Silicon. Local support is the `local` transport plus Ollama in the service list. The real macOS-local story is kwindla's example (see section 9).
- **Pain points from issues** (searched `gh search issues`, sorted by reactions):
  - #5197 (open): ElevenLabs realtime STT re-sends stale partial transcripts, which open phantom user turns.
  - #3829 (open): send-text InputTransportMessageFrame interrupts but does not reach the LLM in speech-to-speech pipelines.
  - #6042 (closed): SmallWebRTC native memory grows 20–50 MiB per finished session (PyAV resamplers suspected).
  - #4628 (closed): bus edge processor echo-loops in-flight frames when two or more workers are briefly active during handoff.
  - #984 (closed, 14 comments): short utterances do not trigger VAD.
  - Pattern: the issues cluster around transport lifecycle, STT partial/final handling, and multi-worker concurrency, not around the core turn logic.

## 2. Smart Turn (pipecat-ai/smart-turn)

- **Repo:** https://github.com/pipecat-ai/smart-turn. 1,630 stars, BSD-2-Clause, pushed 2026-01-29. Current model is v3.2.
- **What it predicts:** Whether the user has finished the phrase, from raw audio (not text). Runs after VAD flags silence and is rerun on the full turn if the user keeps talking.
- **Model:** Whisper Tiny encoder plus a linear classifier, about 8M parameters. CPU build int8, about 8 MB. GPU build fp32, about 32 MB, reported about 1% more accurate.
- **Languages:** 23.
- **Latency (README):** "as little as 10ms on some CPUs, and under 100ms on most cloud instances." Pipecat Cloud reports about 65 ms on a 1x instance using `LocalSmartTurnAnalyzerV3`.
- **Input:** 16 kHz mono PCM, up to 8 s.
- **Training:** Open datasets on Hugging Face (`pipecat-ai/smart-turn-data-v3.2-train` / `-test`). Training runs locally (`train.py`) or on Modal.
- **Accuracy caveat:** The README gives no independent benchmark. A TurnBench paper (search summary, unverified) reports Smart Turn v3.1 interruption recall of about 0.11 versus about 0.95 for VAP, with similar false-positive rates. Treat the detail as unconfirmed, but the point stands: turn-detection models differ widely in recall, so measure on our own audio.

## 3. LiveKit Agents (livekit/agents)

- **Repo / stats:** https://github.com/livekit/agents. 14,881 stars, about 4.0k forks, Apache-2.0, Python, not archived, pushed 2026-10-21. Built on the LiveKit WebRTC SFU.
- **Architecture:** Agent (instructions plus tools), AgentSession (per-user session container), entrypoint, AgentServer (job scheduling and dispatch). Agents can hand off with shared userdata and chat context. Any combination of STT, LLM, TTS, or a realtime model is supported.
- **Speech-to-speech vs cascaded:** Both. Realtime models (e.g. OpenAI `RealtimeModel`) can be swapped in per agent stage.
- **Streaming:** Partial STT and streaming LLM tokens are the default. Specific sentence-chunking strategy not found in the README **(unverified)**.
- **Turn detection:** Two layers.
  - **Endpointing:** VAD (inference.VAD / Silero) plus an endpointing delay (default 0.5 s before a turn is considered complete, max 6.0 s).
  - **Turn detector model:** An open-weights transformer plugin, built on Qwen2.5-0.5B-Instruct (distilled from a 7B teacher), 14 languages in the multilingual model, about 400 MB RAM, and LiveKit's own claim of about 25 ms inference. Needs live STT output, so it cannot be used with a realtime model unless a separate STT runs alongside. Source: LiveKit docs search summary; the 25 ms figure is vendor-reported.
- **Adaptive interruption handling** (docs.livekit.io, fetched): A model analyzes acoustic signals during overlapping speech to decide whether to yield, so backchannels like "uh-huh" do not stop the agent. It runs after VAD and does not need a transcript. Default on for LiveKit Cloud. Self-hosted: set `interruption.mode` to `"adaptive"` in `turn_handling`, with API keys. Other modes: `"vad"` or disabled. Cooldowns: start cooldown 1.0 s (VAD only during the first second of agent speech) and end cooldown 1.0 s (late STT within the last second is kept as a user turn). Falls back to VAD when LiveKit Inference is unavailable. Realtime model caveat: a confirmed backchannel drops the whole buffered turn. No accuracy or latency numbers are published.
- **Echo cancellation:** Browser WebRTC AEC runs only on the client. For agents and telephony, LiveKit suggests its Cloud noise cancellation (Krisp and ai-coustics) on inbound audio. Echo that passes VAD is a common cause of false barge-ins. Source: LiveKit docs search summary.
- **Transport:** WebRTC via LiveKit SFU, plus SIP telephony, RPC and Data APIs. Agents connect to LiveKit Cloud or a self-hosted server.
- **Local models:** Not a local-first design. The README says the stack "can run on your own servers" but does not document fully local model operation. `console` mode gives local audio I/O for testing. Cloud dependency is the main accessibility issue for our case.
- **Latency numbers:** Not in the README. Benchmark summaries cite a median of about 7 barge-ins per 100 calls (VAmoS, unverified).
- **Pain points from issues:**
  - #315 (open, 9 comments): agent speech output is interpreted as user speech. This is the self-hearing problem in our domain.
  - #835 (closed, 17 comments): VAD freezes and fails to detect speech end.
  - #3637 (closed, 47 comments): "process is unresponsive, killing process" errors.
  - #6033 (open): requests a self-hosted adaptive-interruption option (Krisp VIVA), which shows the cloud-only dependency is a known complaint.

## 4. TEN Framework (TEN-framework/ten-framework)

- **Repo / stats:** https://github.com/TEN-framework/ten-framework. 11,186 stars, license "Other" on GitHub (Apache-2.0 with additional restrictions per the README; check LICENSE before reuse), Python agents, Go API server, pnpm/Bun frontend, pushed 2026-10-21.
- **Architecture:** Agents are built from extensions (ASR, LLM, TTS, memory, VAD, turn detection, SIP, avatar integrations). The README does not describe the graph runtime in detail **(unverified)**. Ships a real-time speech-to-speech variant as well as a chained assistant (default example Deepgram, OpenAI, ElevenLabs).
- **Models:** TEN VAD (lightweight streaming VAD) and TEN Turn Detection (credited with full-duplex dialogue). No benchmarks or latency figures in the README.
- **Transport:** RTC and WebSocket. Example setup needs Agora App ID and certificate. Also SIP (Twilio example) and avatar vendors (Trulience, HeyGen, Tavus).
- **Platform:** Docker plus Docker Compose and Node 18 locally, minimum 2 CPU and 4 GB RAM. Codespaces supported. No Apple Silicon or macOS-native guidance.
- **Accessibility fit:** Poor for our target user. Docker, Agora credentials, and a Go + Python + Node toolchain are all setup burdens.
- **Interruption and echo:** Not described in the README.

## 5. Hugging Face speech-to-speech (huggingface/speech-to-speech)

This is the most directly relevant project for a local macOS voice tutor.

- **Repo / stats:** https://github.com/huggingface/speech-to-speech. 13,514 stars, about 1.7k forks, Apache-2.0, Python, pushed 2026-10-21, 1,554 commits.
- **Architecture:** Four-stage cascade VAD → STT → LLM → TTS. Each stage runs in its own thread, connected by queues. Defaults: Silero VAD v5, NVIDIA Parakeet TDT (STT), Qwen3.5-4B (LLM), Qwen3-TTS. Each stage is swappable via CLI flags or YAML. `num_pipelines` runs isolated instances.
- **Turn detection:** Smart Turn v3.2 validates Silero's end-of-speech decisions. A turn tracker manages LISTENING, SOFT_ENDED, ANSWERING, CLOSED states. If speech resumes during a hold, the turn reopens and stale work is discarded.
- **Interruption:** Realtime-protocol `server_vad` with `interrupt_response`, plus `response.cancel` and `conversation.item.truncate`. Barge-in details are otherwise sparse in the README.
- **Echo:** No software AEC. Recommends headphones, or `--local_audio_block_mic_during_playback` so the assistant does not hear itself.
- **Transports:** Local audio (`local` = server plus loopback mic/speaker in one process; `talk` = standalone client). WebSocket `serve` at `ws://127.0.0.1:8765/v1/realtime`, localhost by default. WebRTC is also supported for the Realtime protocol. Tested clients: browser demo, LiveKit Agents, OpenAI Agents SDK (over WebSocket and WebRTC; described as a "tested core subset").
- **Apple Silicon:** On macOS, `local` and `serve` run all three models through MLX (mlx-lm, mlx-audio for Qwen3-TTS, MLX Parakeet for STT). `--mac-optimal-settings` sets MPS as the default device where it applies. Planning guidance: 16 GB unified memory for the default, about 24 GB with llama.cpp. CI on Apple Silicon runs only an install smoke test.
- **Latency:** No end-to-end number in the README. Timing knobs: 196 ms playback buffer for the OpenAI-compatible TTS backend; 800 ms `--speculative_reopen_ms`; 600 ms `--smart_turn_incomplete_delay_ms`; 2 s `--smart_turn_max_wait_ms`; 64 ms `--min_silence_ms`; recommended 384 ms `--min_speech_ms` and 192 ms `--min_speech_continuation_ms`. The server logs per-response STT, LLM, first-audio, and speech-to-audio durations, but publishes no results.
- **Licensing caveat:** Several optional model weights are non-commercial (OmniVoice CC-BY-NC; Phonon 40M CC-BY-NC-4.0). Check model licenses before shipping.
- **Support:** CI covers Linux on Python 3.11–3.14. Windows is out of the matrix. Deprecated engines moved to `archive/`.

## 6. RealtimeSTT (KoljaB/RealtimeSTT)

- **Repo / stats:** https://github.com/KoljaB/RealtimeSTT. 10,200 stars, MIT, Python, pushed 2026-10-18.
- **What it is:** An STT library (not a full agent). Realtime partial transcripts plus a final transcript, with callbacks for recording, VAD, realtime text, transcription, and wake-word events. Optional wake words (Porcupine, OpenWakeWord).
- **VAD:** WebRTC VAD and Silero VAD. The two-stage interaction is not documented in the README. The production WebSocket path does not derive finalization from recorder VAD.
- **Models:** Default faster-whisper (CUDA recommended on NVIDIA). For CPU on Linux x86-64, the README strongly recommends a two-model pattern: a streaming Nemotron ASR as "fast, replaceable realtime text" and Parakeet as "the single authoritative final transcript." Also whisper.cpp, Moonshine, sherpa-onnx, and others as extras.
- **Latency numbers:** Qualitative only ("low-latency"). The "560ms" in the Nemotron bundle name is not explained.
- **macOS:** Only instruction is `brew install portaudio`. No Apple Silicon guidance (MLX is not used here).
- **Known limits (from README):** Python 3.11–3.12 are CI targets. Non-loopback server binds need a bearer token and TLS. Input must be 16-bit mono 16 kHz PCM unless the source rate is passed.

## 7. RealtimeTTS (KoljaB/RealtimeTTS)

- **Repo / stats:** https://github.com/KoljaB/RealtimeTTS. 4,043 stars, MIT, Python, pushed 2026-10-19.
- **Engines:** About 30. Local: SystemEngine, CoquiEngine, KokoroEngine, OrpheusEngine, PiperEngine. Cloud: OpenAI, Azure, ElevenLabs, Cartesia. Free: GTTS, Edge. Recommended: QwenEngine (CPU variant QwenCpuEngine).
- **Streaming:** `feed()` accepts text iterators, so audio starts while the LLM is still generating. Sentence splitting uses stream2sentence (nltk + rule-based consensus by default; Stanza optional). This is sentence-chunked streaming; no phrase-level strategy documented.
- **Latency numbers (QwenEngine, RTX 4090, Linux, 10 warm runs):** Engine TTFT 35 ms; first PCM chunk emitted 35 ms later; silence in chunk 10 ms; predicted audible onset 80.9 ms; RTF 0.108. The page calls these "orientation figures" and not a guarantee. No comparable numbers for CPU or Apple Silicon.
- **Apple Silicon:** CPU wheels for Apple Silicon macOS 11+ and Intel macOS 13+. QwenCpuEngine is CPU-only there. Metal is explicitly out of scope for this release. Local playback needs PortAudio via Homebrew.
- **Limits:** Qwen GPU path needs NVIDIA. x86-64 needs AVX2/FMA/F16C/BMI2. Qwen workflows require Python 3.11 or 3.12. Model weights and voice latents are not bundled.

## 8. RealtimeVoiceChat (KoljaB/RealtimeVoiceChat)

- **Repo / stats:** https://github.com/KoljaB/RealtimeVoiceChat. 3,860 stars, Python + JS. GitHub reports no license. README says MIT for the core. Last push 2025-07-11. The author says the project is community-driven and no longer actively maintained.
- **Architecture:** Browser (Vanilla JS, Web Audio API, AudioWorklets) streams audio over WebSocket to a FastAPI backend. Backend chains RealtimeSTT (Whisper, default `base.en`), an LLM (Ollama default, OpenAI supported), and RealtimeTTS (Kokoro, Coqui, Orpheus). Dynamic silence detection in `turndetect.py`. Interruption is described as "graceful" with no mechanism given.
- **Echo, latency, VAD:** Echo cancellation not mentioned. No latency numbers. The README does not name a VAD component explicitly.
- **Apple Silicon:** Not documented. Installer is Windows-only. Mac users report it working on an M1 (open issue #45), without official guidance. CPU-only is described as "expect slow performance."
- **Fit:** Good reference for a browser-based WebSocket demo. Stale, so do not depend on it.

## 9. kwindla/macos-local-voice-agents (Pipecat example, fully local)

- **Repo / stats:** https://github.com/kwindla/macos-local-voice-agents. 341 stars, no license detected, Python + JS client, pushed 2025-08-26.
- **Stack:** Pipecat with SmallWebRTCTransport (serverless local WebRTC). Silero VAD and smart-turn v2 run in-process. MLX Whisper for STT. Gemma3n 4B via an OpenAI-compatible HTTP server (LM Studio recommended). Kokoro TTS via a custom mlx-audio frame processor. React client based on the voice-ui-kit debug console.
- **Latency claim:** Voice-to-voice "under 800 ms" on an M-series Mac "with relatively strong models." No chip, RAM, or measurement method given.
- **Echo and interruption:** Not addressed. Interrupt handling is described as reconfigurable.
- **Caveats:** External LLM server must be running. First start takes 30 s or more while weights download. No license means we cannot reuse code directly, but the architecture is a useful reference.

## 10. eauchs/speech-to-speech-pipeline

- **Repo:** https://github.com/eauchs/speech-to-speech-pipeline. 10 stars, MIT, pushed 2026-10-07. Described as a local, interruptible (barge-in) STT→LLM→TTS pipeline optimized for Apple Silicon with MLX. Uses MLX Audio with Kokoro and a local OpenAI-compatible LLM (LM Studio or Ollama). Very small community; treat as a reference, not a dependency.

## 11. Vocode (vocodedev/vocode-core)

- **Repo / stats:** https://github.com/vocodedev/vocode-core (formerly vocode-python). 3,806 stars, MIT, Python. Last push 2024-11-15. Status sources conflict. The open-source core appears to have gone quiet, and attention moved to the hosted product. A release list shows v0.1.113 with later pre-release builds **(dates unclear)**.
- **Architecture:** Transcriber / agent / synthesizer pipeline with telephony and WebSocket transports **(from memory; docs fetch returned 404)**.
- **Verdict:** Stale and vendor-led. Do not build on it. Useful only as historical context.

## 12. Other notable projects

- **mlx-audio** (https://github.com/Blaizzy/mlx-audio): 8,082 stars, MIT, pushed 2026-10-21. TTS/STT/STS on MLX (Kokoro, Whisper, Qwen3-TTS, Marvis). This is the library most local Mac voice stacks depend on. High priority to evaluate.
- **Pipecat examples** (https://github.com/pipecat-ai/pipecat-examples): official example apps, BSD-2-Clause.

---

## Cross-cutting findings

### Pipeline architecture
- Cascaded (VAD → STT → LLM → TTS) is still the default. Speech-to-speech (OpenAI Realtime, Gemini Live, Qwen-Omni class) is supported by Pipecat, LiveKit, TEN, and HF. For a local-first Mac tutor, cascaded with MLX components is the only realistic path today.

### Streaming
- All serious frameworks stream partial STT, stream LLM tokens, and chunk TTS by sentence. Time to first audio is the metric that matters.
- RealtimeSTT's Nemotron-partial plus Parakeet-final pattern and HF's speculative-reopen timer are the two designs worth studying for the partial-to-final handoff.

### VAD and end-of-turn
- Silero VAD is the common base. The strongest pattern is VAD → small turn model (Smart Turn v3.x, LiveKit's Qwen-0.5B-based detector) → confirmation delay. HF's timers (600 ms incomplete delay, 2 s max wait) show how many knobs this needs.

### Barge-in
- Raw VAD barge-in causes false cut-offs. Mitigations in use: minimum words (Pipecat), adaptive acoustic interruption (LiveKit), minimum speech duration and reopen windows (HF). Expect this to be a tuning problem, not a solved one.

### Echo cancellation
- None of these frameworks ships reliable software AEC for the local speaker case. LiveKit relies on client WebRTC AEC or Cloud noise cancellation. HF and kwindla say "use headphones" or block the mic during playback. Pipecat and LiveKit issues show self-hearing still happens.

### Latency
- No framework publishes a reproducible end-to-end Apple Silicon number. Figures found: under 800 ms voice-to-voice (kwindla, M-series, unspecified); about 81 ms predicted audio onset for TTS on an RTX 4090 (RealtimeTTS); about 65 to 100 ms for Smart Turn inference; 1.95 s median for Pipecat in one third-party study (unverified). We will need our own measurements.

### Transport
- WebRTC (LiveKit, Pipecat SmallWebRTC, HF optional) or localhost WebSocket (HF, RealtimeVoiceChat). For a single-machine app, localhost WebSocket or in-process local audio is simpler than WebRTC.

### Apple Silicon support
- Real MLX support exists in HF speech-to-speech (first-party), kwindla's example, eauchs's pipeline, and RealtimeTTS's CPU wheels. Pipecat, LiveKit, TEN, and Vocode have no first-party Apple Silicon story.

### Maintenance and license risk
- Active: Pipecat, LiveKit, TEN, HF speech-to-speech, RealtimeSTT, RealtimeTTS.
- Stale: RealtimeVoiceChat (2025-07), Vocode (2024-11), kwindla example (2025-08).
- License traps: TEN ("Apache with additional restrictions"); kwindla example (no license); RealtimeVoiceChat (GitHub reports none, README says MIT); several HF optional model weights are non-commercial.

---

## Takeaways for our MVP

1. **Do not make a Python framework the user-facing core.** Every framework here is a Python service with a multi-process or Docker setup. For a non-technical user, the hard problem is packaging. Plan for a native macOS shell (Swift app or a signed bundle) that runs the models in-process via MLX, or a single bundled Python sidecar with no Docker and no separate LLM server. Use Pipecat or HF speech-to-speech as design references, not as runtime dependencies that the user must install.

2. **Copy HF speech-to-speech's stage layout, not its UI.** VAD, STT, LLM, and TTS each in their own thread with queues, all on MLX, with one config file. It is the closest match to what we need on a Mac, and Apache-2.0 is clean.

3. **Use a turn model on top of VAD, with a short VAD stop.** Silero VAD for speech and endpointing, then a small end-of-turn model (Smart Turn v3.2, about 8 MB int8, BSD-2) to decide whether the user is really done. Set the VAD stop near 0.2 s, as Pipecat recommends, and test the model on our own recordings, because published recall numbers disagree.

4. **Do not trigger barge-in on raw VAD.** Gate interruption with a minimum speech duration (HF uses 384 ms, with 192 ms continuation), a minimum word count (Pipecat), or an adaptive acoustic check (LiveKit). Add a reopen window so a short "uh-huh" does not cancel the tutor's answer.

5. **Design for no echo cancellation.** Default to headphones and show that in onboarding. Add a mic-mute-during-playback option, as HF does. Software AEC is not worth building for the MVP. Track self-hearing (LiveKit issue #315) as a known failure mode and log it.

6. **Split STT into a fast partial and an authoritative final.** Show partials in the UI and send only the final transcript to the LLM. RealtimeSTT's Nemotron-plus-Parakeet pairing is a concrete model combo to evaluate on Apple Silicon.

7. **Stream LLM tokens into sentence-chunked TTS with a playback buffer.** Use RealtimeTTS's `feed()`-with-iterator pattern (or equivalent) and keep track of time to first audio, which is the number that users feel. Start with Kokoro (via mlx-audio) for TTS, since it is the best-supported local option on Mac in this set.

8. **Instrument every stage from day one.** HF logs STT, LLM, first-audio, and speech-to-audio times per response. Copy that, and publish our own numbers on a named Mac configuration, because no framework has a reproducible Apple Silicon benchmark.

9. **Avoid Docker, cloud credentials, and external servers in the install path.** TEN needs Docker and Agora. LiveKit's best features need LiveKit Cloud. Pipecat's kwindla example needs LM Studio running. Each of these would be a support burden for our audience. Bundle the LLM runtime (mlx-lm or llama.cpp) in-process if possible.

10. **Pick dependencies by license and activity, and pin them.** Prefer Apache-2.0, MIT, or BSD components that are still being pushed (Pipecat, HF speech-to-speech, RealtimeSTT, RealtimeTTS, mlx-audio). Avoid RealtimeVoiceChat, Vocode, and unlicensed examples as dependencies. Check each optional model's license before shipping, since several local TTS weights are non-commercial.
