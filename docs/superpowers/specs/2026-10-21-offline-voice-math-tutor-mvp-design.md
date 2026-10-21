# Offline Voice Math Tutor — MVP Design

Date: 2026-10-21
Status: Builder check done; owner answers incorporated; awaiting owner approval

## Intent

A macOS app you can talk to, out loud, to learn math. It talks back like a
patient teacher. Everything runs on the Mac with open-weight models; nothing
leaves the machine after the models download.

The idea itself is not new: ChatGPT, Claude and Perplexity all have voice
modes. What's new is making it **accessible**: free, private, offline, and
easy for anyone to use. The eventual audience is elementary-school students
learning math, set up and supervised by a guardian. A visual board that draws
functions and geometry comes later.

**The MVP exists to answer one question: can a spoken math tutor run entirely
offline on a MacBook and feel good to talk to?** Everything outside that
question is out of scope.

Background research lives in `docs/research/`. Read the "Takeaways" and
"Recommendation" sections of each file before planning.

## Goals

1. A natural, continuous voice conversation about math in **English and
   Spanish**, both from day one.
2. Fully local inference after first-run model download. No network calls
   during a session.
3. Feels like talking to a person:
   - fast replies
   - the tutor can be interrupted
   - the tutor does not cut off a speaker who pauses to think
4. The tutor teaches rather than lectures. It keeps turns short, asks guiding
   questions and checks understanding. This behavior comes from the system
   prompt.
5. An architecture that leaves room for the future visual board without
   rework.

## Success criteria (what "validated" means)

Measured on the **target system: MacBook Pro, Apple M4 Max, 36 GB, macOS
27.0.1** (the owner's development machine), and reported by the in-app timing
display. To keep the result meaningful for ordinary Macs, the app's total
working set should also stay under **~12 GB**; the timing panel reports it.

| Metric | Target |
|---|---|
| End of user speech → first tutor audio | ≤ ~1.0 s (typical) |
| User starts talking while the tutor speaks → tutor audio stops | ≤ ~300 ms |
| 20-minute continuous session | No stutter, no crash, no memory growth that forces swapping |
| Tutoring quality | Explanations are mathematically correct and teacher-like in both English and Spanish, judged by the owner on a fixed set of prompts |

How the clocks are measured (builder's call, see "Calls made"):
- **Reply latency** starts when the turn is declared over: Smart Turn
  says "complete", or the spacebar is released. It stops at the first audible
  TTS sample. The deliberate silence allowance before that point is
  reported separately in the timing panel and is not counted against the
  1.0 s target. Speculative LLM prefill during the pause is allowed but not
  required.
- **Barge-in latency** starts at the VAD speech-onset frame and stops when
  tutor audio is **ducked**, meaning its volume is dropped sharply.
  Interruption is two-step:
  1. on VAD onset, duck tutor audio within 300 ms;
  2. once real speech is confirmed (minimum duration or first ASR word),
     stop playback and cancel generation.

  If speech isn't confirmed, restore the volume and continue.

Prompt set: about 20 prompts per language, drafted by the builder and
reviewed by the owner. Level: elementary to early middle school. That covers
arithmetic, place value, fractions and decimals, basic geometry and area, and
simple patterns and functions.

## Non-goals (MVP)

- Guardian features: monitoring, dashboards, reports.
- Learner profiles, progress memory, session summaries.
- Drawing or visual board rendering. Only the hook for it is in scope; see
  "Reply format".
- Polished distribution: no signed or notarized DMG, no Sparkle updates. A
  developer build is fine.
- Apple's built-in models (Foundation Models, SpeechAnalyzer, the
  AVSpeechSynthesizer voices). Open-weight models only.
- Commercial licensing. The app is non-commercial, so CC BY-NC weights are
  acceptable.
- Speech-to-speech or full-duplex models such as Moshi. The pipeline is
  cascaded.
- Languages other than English and Spanish.

## Anti-goals (would count as failure even if it technically works)

- Requiring the user to install Python, Homebrew, Ollama, LM Studio or any
  external server or tool.
- Requiring headphones when echo cancellation works. Headphones are only a
  fallback (see "Conversation behavior").
- The tutor regularly cutting the speaker off mid-thought.
- The tutor reading math notation aloud literally, for example "three slash
  four" or "x caret two".
- Any network traffic during a tutoring session.

## Constraints

- **Native Apple stack.** Swift and SwiftUI with Apple frameworks wherever
  possible. Inference runs on **Core ML or MLX (MLX Swift)** only: no Python,
  no ONNX Runtime unless a fallback forces it, no external processes.
- **Existing project:** `AgenticTutor.xcodeproj`. It currently has
  `MACOSX_DEPLOYMENT_TARGET = 27.0`, Swift 5.0, App Sandbox enabled, and
  multi-platform supported platforms. The MVP targets **macOS only**. Keeping
  the macOS 27.0 deployment target is fine, since the target system runs
  27.0.1. The
  sandbox needs microphone access and outgoing network access (for the model
  download).
- **Memory:** total app working set under ~12 GB, so the result carries over
  to 16 GB Macs.
- **Licenses:**
  - The app will be **open source**.
  - GPL dependencies are allowed, but if any are used the app's own license
    must be GPL-3.0-compatible. The owner picks the final license; GPL-3.0 is
    the safe default if a GPL dependency lands.
  - Avoid AGPL.
  - CC BY-NC model weights are allowed. They are downloaded at first run, not
    committed to the repo.

## Decided stack

| Stage | Choice | Runtime | Fallback |
|---|---|---|---|
| Audio I/O + echo cancellation | `AVAudioEngine` with voice processing enabled on the input node | macOS | — |
| Voice activity detection | **Silero VAD v6** | Core ML (via FluidAudio's VAD, or a self-converted model) | TEN VAD (native arm64 C library) |
| End-of-turn detection | **Pipecat Smart Turn v3.2** (~8 MB), run when the VAD reports a pause | Core ML (convert, or use the third-party TheStage conversion) | Longer VAD silence timeout |
| Speech-to-text | **NVIDIA Nemotron 3.5 ASR Streaming Multilingual 0.6B** (true streaming, 40 locales; use es-US, or es-MX if the model card lists it, for Mexican Spanish) | MLX 5-bit (~539 MB, ~800 MB peak) or Core ML INT8 (~612 MB), via the Soniqo Swift port | Parakeet TDT v3 via FluidAudio (batch, not streaming) |
| Tutor LLM | **Qwen3.5-4B Instruct, 4-bit** as the baseline. A larger Qwen3.5 variant may be used on ≥ 32 GB Macs if it stays inside the latency and ~12 GB targets | MLX Swift | Gemma 3n |
| Text-to-speech | **Gradium Phonon 40m multilingual** (EN/ES/FR/DE/PT, 102 voices, streams 80 ms frames, ~75 MB) | Core ML (Gradium's Swift guide) or MLX-Audio | Kokoro-82M (MLX) |

Notes:
- Verify the exact license of the Nemotron model on its Hugging Face card
  before shipping.
- Phonon 40m is **gated** on Hugging Face (CC BY-NC 4.0). For the MVP
  developer build, the download screen asks once for a Hugging Face access
  token and stores it in the Keychain. The model's terms must already be
  accepted on that account. Self-hosting is deferred.
- The model is sized to the Mac's memory automatically. The user never picks
  a model by name.

## Conversation behavior (decided)

- **Pipeline:** cascaded and streaming. VAD → streaming ASR (partial captions
  shown live) → end-of-turn → LLM token stream → TTS in phrase-sized chunks →
  playback.
- **End of turn:**
  - The VAD detects a pause and Smart Turn judges whether the speaker has
    finished.
  - The silence allowance is longer than adult-oriented voice apps use,
    because kids pause mid-thought.
- **Holding the spacebar means "I'm still thinking."** While it is held, the
  turn never ends, regardless of silence.
- **Barge-in (interruption):**
  - When the user speaks while the tutor is talking, stop playback and cancel
    the LLM and TTS generation immediately.
  - Gate this on real speech, not on any noise. A short minimum speech
    duration, or the first ASR word, avoids triggering on coughs or bumps.
- **Cheap recovery from early cutoffs:** if the user keeps talking right
  after a turn was closed:
  1. cancel the in-flight reply;
  2. join the previous and the new user speech;
  3. answer the combined turn.
- **Echo cancellation:** Apple's voice processing on the input node, so the
  tutor doesn't hear itself through the speakers. No headphones are needed.
  - **Fallback:** if voice processing is unavailable, or a quick self-test
    shows the tutor's audio leaking into the mic, ask the user to wear
    headphones. A one-line prompt is enough for the MVP.
  - Barge-in stays on in both cases.
- **Language:**
  - Language is decided **per turn**. Use the ASR's detected language if the
    Nemotron port exposes it; otherwise use the language setting.
  - Mixed English/Spanish turns get a reply in the language of the setting.
  - The TTS voice switches with the reply language.
  - No separate language-ID model in the MVP.
- **Spanish variety:** Mexican Spanish. Use a Latin American Phonon voice.
  Speech uses Mexican conventions: decimal "punto" ("tres punto cinco") and
  "por" for multiplication.
- **Math vocabulary:** if the ASR supports biasing or a vocabulary hint, feed
  it math terms in both languages.

## Reply format (the hook for the future visual board)

The LLM does not emit free text straight to TTS. Each reply has:
- **Speech:** what to say, written for the ear. For example "three quarters"
  / "tres cuartos", never "3/4".
- **Actions:** structured items. In the MVP the only action is "show this
  expression" (e.g. LaTeX or plain text), rendered as text on screen. The
  future board adds draw actions to the same channel.

The format must still allow streaming speech to the TTS before the whole reply
is generated. Use structured output, a tag protocol or tool calls, whichever
streams cleanly with MLX Swift.

## UI (MVP)

A single window containing:
- a start/stop conversation control;
- a clear listening / thinking / speaking state indicator;
- live captions for both sides;
- the current expression from "show" actions;
- a text field so the user can type instead of speak;
- a language setting.

The app's wording presents it as a general math tutor and does not mention
children. A **developer timing panel** shows per-stage latency and memory
(VAD, end-of-turn, ASR final, LLM first token, TTS first audio, barge-in
stop).

First launch shows a download screen with progress and sizes. After that the
app runs offline.

## Risks and the de-risking spike

Before building the full pipeline, run a **throwaway spike, about a day of
work**. It checks:
1. **Phonon Spanish quality**, by listening, against Kokoro.
2. **Nemotron accuracy** in English and Mexican Spanish, including math words
   and mid-thought pauses. Use the owner's and other adults' recordings; child
   recordings are out of scope for the MVP. If accuracy is poor, try
   Parakeet v3.
3. **Qwen3.5-4B tutoring quality** in both languages on a fixed prompt set,
   and its tokens/s on an M1 Pro 16 GB.
4. **Peak memory** with all models loaded at once.
5. **Echo leakage** with voice processing on the target system's built-in
   speakers.

Other known risks:
- Accuracy on child speech (Nemotron and Smart Turn) is unverified. It is
  tested with adults only and deferred past the MVP.
- The Swift ports of Nemotron, Smart Turn and Phonon are community or
  third-party code.
- Phonon was released 2026-10-20, so its quality numbers are self-reported.

## Calls made (by Claude, not confirmed by the owner)

- How latency clocks are measured, and the two-step barge-in (duck, then
  stop).
- Per-turn language selection with a fallback to the setting; no separate
  language-ID model.
- A Hugging Face token in the download screen for the gated Phonon weights.
- A ~12 GB working-set budget, so results carry over to 16 GB Macs.
- GPL-3.0 as the default app license if any GPL dependency is used.
- The builder drafts the prompt set and the owner reviews it; elementary to
  early-middle-school level.

## Left to the builder

- **Models:**
  - Core ML vs MLX for each model where both exist. Pick by measured latency
    and memory.
  - Whether FluidAudio or self-converted models are used for VAD and Smart
    Turn.
  - The exact larger LLM for ≥ 32 GB Macs.
- **Conversation tuning:**
  - Exact VAD thresholds, silence timeouts and barge-in gates.
  - Exact system prompt wording, within the behavior described above.
- **Engineering:**
  - Concurrency design: actors, queues, how stages are wired.
  - Where models are stored and how downloads resume.
- **UI:** visual design.
