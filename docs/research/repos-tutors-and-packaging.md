# Research: open-source AI tutors and consumer local-AI Mac packaging

Snapshot date: 2026-10-21. Star counts and push dates come from `gh repo view` / `gh search repos` on that date. Items marked "unverified" came only from search snippets or were not confirmed in a primary source.

Scope: (1) open-source AI tutor and language-practice voice projects, and how they structure tutoring; (2) how consumer local-AI Mac apps package, onboard, and update.

---

## Part 1: AI tutor and language-practice projects

| Project | Repo | Stars | Last push | License | Language | Notes |
|---|---|---|---|---|---|---|
| LexiLingo | https://github.com/InfinityZero3000/LexiLingo | 49 | 2026-10-19 | MIT | Python | Most complete architecture found (see below) |
| Dialekt | https://github.com/cristianodabc/dialekt | 24 | 2026-09-01 | Apache-2.0 | Elixir | CEFR + register, mistake review queue |
| loqui | https://github.com/mikhailvs/loqui | 0 | 2026-06-26 | MIT | Python | "Pedagogy in code", push-to-talk voice loop, new (June 2026) |
| LocalTeacher | https://github.com/FaceNach/LocalTeacher | 0 | 2026-07-29 | MIT | Go | Ollama + whisper.cpp + Piper, CLI conversation tutor |
| Mr. Ranedeer AI Tutor | https://github.com/JushBJJ/Mr.-Ranedeer-AI-Tutor | 29,551 | 2026-10-21 | none stated | prompt only | Prompt-only GPT-4 tutor, marked DISCONTINUED. Largest tutor repo by stars |
| tutor-gpt (Plastic Labs) | https://github.com/plastic-labs/tutor-gpt | 931 | 2026-10-20 | GPL-3.0 | TypeScript/JS (unverified) | Theory-of-mind user modeling via Honcho |
| ChatTutor | https://github.com/HugeCatLab/ChatTutor | 1,313 | 2026-10-20 | AGPL-3.0 | unverified | "Visual and interactive AI tutor". Not reviewed in depth |
| ThirtyTutors | https://github.com/wiss84/thirtytutors | 4 | 2026-10-20 | "Other" | unverified | Self-hosted speech-to-speech tutor with avatars. Needs a Gemini API key per search snippet |
| ollama-vox | https://github.com/maadhav-codes/ollama-vox | 0 | unverified | MIT | Swift/Python (unverified) | macOS menubar voice assistant: MLX Whisper + Ollama + Kokoro TTS (per search snippet) |

Voice-stack references (not tutors, but relevant to the voice loop):

| Project | Repo | Stars | Last push | License | Language | Notes |
|---|---|---|---|---|---|---|
| ollama-voice-mac | https://github.com/apeatling/ollama-voice-mac | 519 | 2025-08-21 | AGPL-3.0 | Python | Closest "Ollama + Whisper + voice on Mac" project, but stale (about 14 months since last push) |
| RealtimeVoiceChat | https://github.com/KoljaB/RealtimeVoiceChat | 3,860 | 2025-07-11 | none stated | Python | Streaming speech-to-speech conversation. Stale |
| Pipecat | https://github.com/pipecat-ai/pipecat | 16,693 | 2026-10-21 | BSD-2-Clause | Python | Voice-agent framework. Active, but a server-side Python stack, not a packaged app |

Gap: searches for "Speak"-style commercial clones and "Khanmigo-like" open-source projects returned nothing of substance. Khanmigo itself is closed. No open-source Speak clone with real traction turned up.

### 1a. How the tutors structure tutoring

**LexiLingo** (MIT, Python). Most architecture detail of any project reviewed.
- Curriculum: CEFR-tagged courses A1 to C2, with units, lessons, and exercises. Prerequisite chains are explicit (for example, Past Simple, then Past Perfect, then Reported Speech).
- Prompting: "Lexi Chat" is "contextual conversation powered by the TRACECAG pipeline." Each query is routed through five features (intent, level, seed concepts, neighborhood, profile state). A gate decides whether a cached answer can be reused.
- Correction: a Diagnose node maps errors to knowledge-graph concept IDs before generation. Pronunciation feedback is included.
- Progress memory: a KuzuDB knowledge graph of concept mastery, plus a Redis per-user cache (mastery scores, error history, CEFR level). SM-2 spaced repetition for vocabulary.
- Voice: a WebSocket stream for STT and TTS, with Faster-Whisper for STT and Piper for TTS. Pronunciation scoring uses a HuBERT model.
- Session summaries: not described.
- Takeaway: this is far heavier than an MVP needs (graph DB, Redis, Docker). Its useful idea is the explicit level and concept state, not the infrastructure.

**Dialekt** (Apache-2.0, Elixir).
- Setup: the learner picks a CEFR level (A1 to C2) and a formal or informal register. The page says these "control vocabulary and grammar complexity." How the level is enforced in prompts or output checks is not described.
- Persona: replies are in the target language. Each reply includes IPA, a native-language phonetic guide, a translation, and usually a follow-up question.
- Correction: for target-language input, the learner's original phrase stays visible, genuine errors are explained, and the correction is shown separately. Romanized input for non-Latin scripts is not logged as a mistake.
- Progress memory: genuine errors go automatically into a per-configuration review queue (Active, Learned, All). Deleting a chat session keeps its saved corrections. Deleting the configuration removes its history.
- Voice: uses the browser Web Speech API for both STT and TTS, so it is not local. The page notes recognition may need internet access.
- LLMs: Anthropic, OpenAI, OpenRouter. Not local-capable as shipped.

**loqui** (MIT, Python). Pedagogy is encoded in the harness, not the prompt.
- Turn logic: five "drives" (Repair, Review, Progress, Engage, Consolidate) score candidate moves. An arbiter vetoes invalid moves (for example, quizzing a word not yet taught) and selects one. "The LLM only realizes moves."
- Curriculum: frequency-ordered vocabulary files per language. A forgetting-curve scheduler governs review timing.
- Feedback: the LLM grades free speech, limited to delayed production. Correction style is not described.
- Voice: push-to-talk in the browser (HTTPS needed for the mic). faster-whisper STT, the LLM replies, edge-tts speaks it. About 2 to 3 seconds per turn on a warm local model. No VAD.
- LLM: any Ollama endpoint (example: qwen3:8b), or the `claude -p` CLI as fallback.
- Session summaries: not described.

**Mr. Ranedeer** (prompt only, no license, discontinued).
- Parameters: depth (elementary to PhD), learning style (VARK-like), communication style (Socratic, Story Telling, Layman, etc.), tone, reasoning frameworks, language.
- Flow: `/config`, `/plan` (lesson plan), `/start`, `/continue`, `/test` (assessment).
- No progress memory and no summaries.
- Takeaway: the config-as-parameters pattern (depth, style, tone) is easy to copy in a setup screen. Its license is unstated, so copy the idea, not the text.

**tutor-gpt** (GPL-3.0, Plastic Labs).
- Uses Honcho to build per-user representations. The tutor "updates its own prompts" from them. Persistent learner state lives outside the app.
- Needs a hosted backend (Supabase, Honcho). Not local.
- Takeaway: a useful reference for a "learner model" concept, but its infrastructure is wrong for an offline app.

**Common patterns across the tutors**
- Explicit level (CEFR or depth) and register chosen during setup.
- Target-language replies with a native-language gloss, so learners are not stranded.
- Corrections separated from the conversation turn, not inline rewrites.
- Mistake log or review queue as the main "memory of progress". Session summaries are rare; none of the projects does them well.
- Most projects with real voice use Faster-Whisper or Whisper for STT and Piper or edge-tts for TTS. Browser Web Speech API is used by Dialekt but is not local.

---

## Part 2: How consumer local-AI Mac apps package and onboard users

| App | Repo / source | Stars | Last push | License | Shell / stack | Distribution |
|---|---|---|---|---|---|---|
| Ollama (desktop app) | https://github.com/ollama/ollama | 184,164 | 2026-10-21 (v0.40.7, 2026-10-18) | MIT | Go backend, React UI in `app/ui`, Objective-C updater in `app/updater/updater_darwin.m` | Direct DMG (`ollama.com/download/Ollama.dmg`), Homebrew |
| LM Studio | closed source (CLI `lms`, SDKs, and `llmster` are open source) | n/a | n/a | proprietary, free for personal and work use since July 2025 | Not confirmed (Electron not verified) | Direct download |
| Jan | https://github.com/janhq/jan | 45,028 | 2026-10-21 (v0.8.7, 2026-10-20) | Apache-2.0 (LICENSE file, with attribution request) | Rust + Tauri v2 (`src-tauri`) | Direct download, Flatpak |
| Osaurus | https://github.com/osaurus-ai/osaurus | 8,065 | 2026-10-21 | MIT | Native Swift, Apple Silicon only, no Electron | DMG (two SKUs), Homebrew cask |
| VoiceInk | https://github.com/Beingpax/VoiceInk | 6,884 | 2026-10-21 (v2.22, 2026-10-01) | GPL-3.0 | Native Swift + whisper.cpp, Sparkle updater | Paid direct download (tryvoiceink.com), Homebrew cask, source build (`make local`) |
| Enchanted | https://github.com/gluonfield/enchanted | 6,014 | 2026-07-07 | Apache-2.0 | Native Swift/SwiftUI (macOS, iOS, visionOS) | Mac App Store, source |
| Handy | https://github.com/cjpais/Handy | 34,267 | 2026-10-21 | MIT | Rust + Tauri v2, Vite/TS frontend | Installers, Homebrew, winget, .deb |
| Hex | https://github.com/anomalyco/hex (replaces archived kitlangton/Hex) | 471 | 2026-10-21 | MIT | Native Rust, on-device ASR | Signed DMG, Homebrew cask, built-in updater |
| Buzz | https://github.com/chidiwilliams/buzz | 22,124 | 2026-10-17 | MIT | Python (Qt) + Whisper | Installers |
| Superwhisper | closed source | n/a | n/a | commercial | native macOS | Direct download, App Store activation |
| MacWhisper | closed source | n/a | n/a | free tier + €64 Pro | native macOS (not confirmed) | Gumroad or Mac App Store |
| Msty | closed source (CloudStack, LLC) | n/a | n/a | commercial | not confirmed | Direct download |

Gap: no reliable confirmation for Msty's shell, offline guarantees, or onboarding, and Jan's hardware detection is not verified (searches returned only third-party mirrors).

### 2a. App shell technology

- **Native Swift/SwiftUI**: Osaurus (Apple Silicon only, no Electron, sandbox via Apple's Containerization framework), VoiceInk, Enchanted. Native gives the cleanest microphone and Accessibility permission UX, small footprint, and no webview.
- **Tauri (Rust + system WebView)**: Jan and Handy. Small shell, cross-platform. Handy and Hex both need macOS Input Monitoring and Accessibility permissions for global hotkeys.
- **Go + web UI**: Ollama's desktop app (Go backend, React in `app/ui`, native Objective-C updater on macOS).
- **Electron**: not confirmed for any of the listed apps. LM Studio's shell was not verified.

### 2b. Bundling vs on-demand model download

- **On-demand, with a small installer**: Osaurus standard build is about 70 MB and picks a model in onboarding. Handy downloads Whisper (Small 487 MB, Medium 492 MB, Large 1.1 GB, Turbo 1.6 GB) and Parakeet (0.73 GB) on demand. Hex downloads during setup from huggingface.co. Superwhisper's first mode uses cloud models.
- **Bundled "full" SKU**: Osaurus also ships a roughly 4 GB "full" DMG with a model included (Raptor 0.6), hosted on Hugging Face. Two SKUs cover the bandwidth-vs-offline tradeoff.
- **Runtime dependency on Ollama**: Enchanted's App Store version does not bundle a model runtime. Its README says "you will need to run your own Ollama server." This is the single biggest friction point for non-technical users in this set.

### 2c. Hardware detection and model-size recommendations

- Few apps do this well in public. LM Studio shows memory-fit estimates, but user reports show they are wrong in both directions. One user had a 22.9 GB estimate block a model that actually used about 11.5 GB. Another saw a model over 70 GB marked "Likely too large" while usage was capped near 64 GB. LM Studio's own docs say only "choose a 4-bit option or higher if your machine is capable enough."
- Osaurus and Handy let users choose a model explicitly in onboarding and show sizes. Handy lists sizes in the README and recommends Parakeet Unified 0.6B as the manual default.
- Jan's docs (via a third-party mirror, unverified) say to keep model memory under 80% of system RAM.
- Generic guidance from search results: 8 GB Macs can run small models with modest context. 16 GB is the recommended floor for 7B to 8B models. LM Studio's docs say 16 GB+ is recommended on Mac.

### 2d. First-run and onboarding

- **Superwhisper** (documented, macOS 14+): drag to Applications, launch, grant two permissions (Microphone, Accessibility), test the mic, choose a shortcut, then complete a practice dictation. Skipped permissions can be granted later in System Settings. The onboarding model download gained a skip button in 2.9.0 (January 2026). The first mode uses cloud models by default.
- **Hex** (documented): setup downloads the transcription model. Users drag the Hex tile into Input Monitoring and Accessibility by hand. Microphone is a standard prompt.
- **Handy** (documented): launch, grant microphone and accessibility, configure a shortcut in Settings. The README describes no further onboarding.
- **LM Studio**: no guided onboarding documented. The user searches Discover (Cmd+2), picks a Hugging Face model, and chooses a quantization variant (Q4, Q8, and so on).
- **MacWhisper**: onboarding and permission flow not covered in the page reviewed.

### 2e. Mic permission handling

- Apps that do global hotkeys (Hex, Handy, Superwhisper, VoiceInk) need Accessibility or Input Monitoring in addition to the microphone. These are the most confusing prompts for non-technical users.
- VoiceInk's build notes say ad-hoc signed builds "may require macOS permissions again after rebuilding." This is a TCC-permission symptom of unstable code signing.
- A tutor app that is a window rather than a hotkey dictation tool needs only the microphone permission. That is a simpler story.

### 2f. Offline guarantees

- Osaurus: "Works fully offline with local models... nothing leaves your Mac unless you choose." Model download still needs the network.
- Handy and Hex: transcription is local. Model download needs huggingface.co (and download.moonshine.ai for Hex voice commands).
- MacWhisper: local models keep sensitive content on the Mac, but cloud is supported via API keys. Data only stays local when a local model is selected.
- Superwhisper: cloud by default on first run.
- Msty: "zero product telemetry" claimed. It does not explicitly claim offline operation.

### 2g. Code signing, notarization, distribution

- **Signed and notarized DMG**: Hex (signed DMG; notarization not mentioned in the README reviewed). Ollama DMG direct download.
- **Homebrew cask**: Osaurus, VoiceInk, Hex, Handy, Ollama. Homebrew 5.0 deprecated casks without code signing, and brew.sh says Homebrew will "disable all Homebrew/homebrew-cask casks that fail Gatekeeper checks in September 2026." That date has already passed as of this snapshot. Whether the change has landed was not verified. `--no-quarantine` and `--quarantine` are deprecated.
- **Gatekeeper**: secondary sources report that macOS 15 (Sequoia) removed the Control-click bypass for unsigned apps. Users must use System Settings → Privacy & Security. This was not verified against an Apple primary source.
- **App Store**: Enchanted (Mac App Store plus source). MacWhisper is also on the Mac App Store. Sandboxing rules limit what the app can spawn, which is why Enchanted delegates to an external Ollama server.

### 2h. Update mechanism

- **Sparkle**: VoiceInk includes Sparkle (confirmed in `project.pbxproj`). Sparkle 2 verifies updates with EdDSA signatures plus Apple code signing. The appcast is a static RSS file hosted on any web server. Setup needs `SUFeedURL` and `SUPublicEDKey` in Info.plist. The `generate_appcast` tool produces signed appcasts and deltas. Sparkle 2 supports sandboxing. Source: Sparkle upstream README mirror (not the official docs site).
- **Custom updater**: Ollama uses its own updater (`app/updater/updater_darwin.m`), not Sparkle.
- **Built-in updater**: Hex and Osaurus (in-app updates; Osaurus's Homebrew build also uses in-app updates). Hex has a `DisableUpdates` preference for organizations.

---

## Takeaways for our MVP

1. **Make the default install tiny and download the model on first run, with progress and a size shown.** Osaurus (70 MB DMG), Handy, and Hex all do this. Offer a second "full offline" DMG only if the bandwidth tradeoff justifies it.
2. **Do not require a separate Ollama install.** Enchanted's App Store build makes users run their own Ollama server, which is exactly the friction to avoid. Either embed the runtime (llama.cpp or MLX) or have the app manage a bundled Ollama process.
3. **Ask for only the microphone permission.** A windowed tutor does not need the Accessibility or Input Monitoring permissions that hotkey dictation apps require. Show a pre-prompt explaining the microphone request before the system dialog, and a mic test step (Superwhisper's flow).
4. **Pick the model by RAM tier, not parameter count.** Offer three presets (for example "Quick", "Balanced", "Best") mapped to RAM bands. Do not copy LM Studio's memory-fit estimates, which users report are unreliable. Show size and "fits your Mac" from your own table.
5. **Ship a signed, notarized DMG with Sparkle (EdDSA appcast) from day one.** Homebrew is disabling non-signed casks, and macOS no longer offers a simple Control-click bypass. Treat Homebrew as a secondary channel. Keep the Sparkle public key stable so updates never break TCC permissions (VoiceInk's rebuild issue).
6. **Choose a native SwiftUI shell.** Osaurus, VoiceInk, and Enchanted show the cleanest mic and sandboxing story on macOS. Tauri (Jan, Handy) is viable but adds a webview and cross-platform concerns you do not need for a Mac-only MVP. Keep the Python voice stacks (ollama-voice-mac, loqui) out of the shipped app.
7. **Copy the tutor's setup-screen parameters, not the prompts.** Pick a level (CEFR-like, or beginner/intermediate/advanced), a register (formal/informal), and a tone, as Dialekt and Mr. Ranedeer do. Keep the native-language gloss toggle. Mr. Ranedeer and tutor-gpt have no clear license for copying text, so write original prompts.
8. **Make progress memory a local, inspectable mistake log.** Dialekt's review queue (Active, Learned, All) and its rule that deleting a session keeps corrections is the closest pattern to "memory of learner progress." Store it in SQLite on the Mac. Session summaries are not solved in OSS, so treat them as a stretch goal.
9. **Make the "works offline" claim precise and verifiable.** Default to local models. State explicitly that the network is used only for model download. Avoid Superwhisper's cloud-first default and Msty's unverified claims.
10. **Choose the license before copying code.** LexiLingo and Dialekt are MIT and Apache-2.0, which allow reuse. VoiceInk, ollama-voice-mac, and tutor-gpt are GPL/AGPL and would constrain a closed-source app. Ollama, Handy, Osaurus, and Hex are MIT and safe to reuse patterns from.

Note on method: no repositories were cloned or run. All claims come from `gh` metadata, repository files fetched through `gh api`, README pages, and web search snippets. Items marked "unverified" should be checked against primary sources before they drive decisions.
