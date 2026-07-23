# WisprFree 🎙️

**Talk to your Mac. Get back clean, polished text — in any app, in your voice, with your own names spelled right.**

WisprFree is a free, open-source, menu-bar dictation app for macOS — a Wispr Flow / Superwhisper alternative where you bring your own AI and your data stays yours. It was born out of a specific frustration: dictation tools transcribe *exactly* what you say — every "um", every false start, every pause — and mangle any name they haven't heard before. If English isn't your first language, or you write fiction full of invented names, raw speech-to-text is barely usable.

So WisprFree does it in two steps: a **local speech model** hears you (fast, private, free), then an **LLM cleans it up** — grammar fixed, fillers gone, your glossary of names applied — and the result lands straight in whatever app your cursor is in.

## Download

Grab the latest `.zip` from [**Releases**](https://github.com/surya758/wisprfree/releases/latest), unzip, and move **WisprFree.app** to /Applications. Apple Silicon, macOS 14+.

> The build is signed but not notarized (no paid Apple account), so on first launch **right-click → Open → Open**, or run `xattr -dr com.apple.quarantine /Applications/WisprFree.app`. After that it **updates itself** automatically.

## How you use it

| Key | Action |
|---|---|
| **Hold Fn** | Push-to-talk: record while held, release to insert |
| **Fn + Space** | Hands-free: keep talking, hands off the keyboard |
| **Tap Fn** | Stop a hands-free recording and insert |
| **Esc** | Cancel — discard the recording (or an in-progress transcription) |

An overlay at the bottom of the screen shows a live waveform while you speak. All hotkeys are remappable in Settings (bare modifiers, F-keys, and combos all work).

> **Fn key tip:** set System Settings → Keyboard → *"Press 🌐 key to"* = **Do Nothing**, or macOS will helpfully open the emoji picker every time you tap Fn.

## What's inside

**🖥️ Local speech recognition** — pick your engine in Settings → Models, downloaded on first use and cached:

- **Parakeet TDT v2 / v3** (NVIDIA) — near-instant on the Apple Neural Engine; v2 for English, v3 for 25 languages
- **Whisper Large v3** (OpenAI) — heavyweight accuracy, ~3 GB
- **Cohere Transcribe** — strong multilingual, including Chinese

**✨ Bring-your-own AI cleanup** — pick a provider in Settings → Models:

- **Google Vertex AI** — uses your `gcloud` login, no API key
- **Google Gemini API** — free API key from [AI Studio](https://aistudio.google.com)
- **OpenAI-compatible** — any endpoint that speaks chat-completions: OpenAI, OpenRouter, Groq, a local Ollama… you set the base URL and model

API keys live in your **macOS Keychain**, never in a config file. No provider configured? Raw local transcription still works, fully offline — and if your provider ever errors mid-dictation, WisprFree inserts the raw transcript rather than eating your words.

**🎭 Modes** — dictation isn't one-size-fits-all. Switch from the menu bar:

- **Casual** — light cleanup for messages and notes; keeps your tone, doesn't formalize
- **Writing** — aggressive cleanup for prose, with your name dictionary applied
- **Professional** — clear, punctuated business writing

Every mode's prompt is **editable in-app** (Settings → Modes) — reshape any of them into whatever you need.

**📖 Dictionary** — teach it your world. Add character and place names, optionally with their common mishearings, and the cleanup model corrects them in context.

**🖊️ How it lands** — choose in Settings → General → Output:

- **Paste** — fast, via the clipboard (restored afterward)
- **Type characters** — synthesizes the text directly: no clipboard, works in terminals and apps that ignore ⌘V, and never leaks into clipboard managers
- **Copy only** — leave it on the clipboard to place yourself

**⚙️ Plus the small stuff**

- **Live transcription** (optional) — see the words appear as you speak
- **Cancel window** — an optional grace period with a countdown before the text inserts, so you can abort
- **Microphone picker**, **start/stop sounds**, **launch at login**
- **Insights** — words dictated today, your streak, and how much typing time you've saved
- **Auto-updates** via [Sparkle](https://sparkle-project.org), signed with an EdDSA key

Everything runs from a native **menu-bar app** with a System Settings-style preferences window. Transcription happens on-device; nothing leaves your Mac unless you pick a cloud AI for the cleanup step.

## Build from source

```sh
brew install xcodegen   # once
./install.sh            # build (Release) → /Applications/WisprFree.app → launch
```

First launch walks you through everything: microphone + Accessibility permissions (Accessibility powers the hotkeys and typing into other apps), choosing an AI provider, and a test box to try your first dictation. Rerun it anytime from Settings → About → *Show Welcome Guide*.

Cutting a release is one command: bump the version in `project.yml`, then `./release.sh "notes"` (builds, signs, updates the Sparkle appcast, tags, and publishes). Commits follow [Conventional Commits](https://www.conventionalcommits.org), enforced by a shared git hook.

## Where things live

| What | Where |
|---|---|
| Dictionary, history, stats | `~/Library/Application Support/WisprFree/` |
| Speech models (Parakeet, Cohere) | `~/Library/Application Support/FluidAudio/` |
| API keys | macOS Keychain |

## Built on the shoulders of

[FluidAudio](https://github.com/FluidInference/FluidAudio) (Parakeet & Cohere CoreML runtimes) · [WhisperKit](https://github.com/argmaxinc/WhisperKit) (Whisper on CoreML) · [Sparkle](https://sparkle-project.org) (updates) · your AI provider of choice · and a novelist who got tired of typing.

## License

MIT — do what you like. Contributions welcome; open a PR.
