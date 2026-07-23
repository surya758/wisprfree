# WisprFree 🎙️

**Talk to your Mac. Get back clean, polished text — in any app, in your voice, with your characters' names spelled right.**

WisprFree is a free, open, menu-bar dictation app for macOS. It was born out of a specific frustration: dictation tools transcribe *exactly* what you say — every "um", every false start, every pause — and mangle any name they haven't heard before. If English isn't your first language, or you write fiction full of invented names, raw speech-to-text is barely usable.

So WisprFree does it in two steps: a **local speech model** hears you (fast, private, free), then an **LLM cleans it up** — grammar fixed, fillers gone, your glossary of names applied — and the result is typed straight into whatever app your cursor is in.

## How you use it

| Key | Action |
|---|---|
| **Hold Fn** | Push-to-talk: record while held, release to insert |
| **Fn + Space** | Hands-free: keep talking, hands off the keyboard |
| **Tap Fn** | Stop a hands-free recording and insert |
| **Esc** | Never mind — discard the recording |

A little pill at the bottom of your screen shows a live waveform while you speak. All three hotkeys are remappable in Settings (bare modifiers, F-keys, and combos all work).

> **Fn key tip:** set System Settings → Keyboard → *"Press 🌐 key to"* = **Do Nothing**, or macOS will helpfully open the emoji picker every time you tap Fn.

## What's inside

**🖥️ Local speech recognition** — pick your engine in Settings → Models, downloaded on first use and cached:

- **Parakeet TDT v2 / v3** (NVIDIA) — near-instant on the Apple Neural Engine; v2 for English, v3 for 25 languages
- **Whisper Large v3** (OpenAI) — heavyweight accuracy, ~3 GB
- **Cohere Transcribe** — strong multilingual, including Chinese

**✨ AI cleanup** — bring whichever provider you like:

- **Google Vertex AI** — uses your `gcloud` login, no API key
- **Google Gemini API** — free API key from [AI Studio](https://aistudio.google.com)
- **OpenAI-compatible** — any endpoint that speaks chat-completions: OpenAI, OpenRouter, Groq, a local Ollama… you set the base URL and model

API keys live in your **macOS Keychain**, never in a config file. No provider configured? Raw local transcription still works, fully offline — and if your provider ever errors mid-dictation, WisprFree inserts the raw transcript rather than eating your words.

**🎭 Modes** — dictation isn't one-size-fits-all. Switch from the menu bar:

- **Casual** — light cleanup for messages and notes; keeps your tone, doesn't formalize
- **Writing** — aggressive cleanup for prose, with your name dictionary applied
- **Professional** — clear, punctuated business writing

Every mode's prompt is **editable in-app** (Settings → Modes), so you can reshape any of them into whatever you need.

**📖 Dictionary** — teach it your world. Add character and place names, optionally with their common mishearings, and the cleanup model corrects them in context.

**📊 Insights** — words dictated today, your streak, and how much typing time you've saved.

## Setup

```sh
brew install xcodegen   # once
./install.sh            # build (Release) → /Applications/WisprFree.app → launch
```

Requirements: Apple Silicon Mac, macOS 14+.

Commits follow [Conventional Commits](https://www.conventionalcommits.org)
(`feat:`, `fix:`, `chore:`, …); `install.sh` points git at the shared
`.githooks` so the format is checked on commit.

First launch walks you through everything: microphone + Accessibility permissions (Accessibility powers the hotkeys and typing into other apps), choosing an AI provider, and a test box to try your first dictation. Rerun it anytime from Settings → About → *Show Welcome Guide*.

The app **updates itself** via [Sparkle](https://sparkle-project.org) — it checks
daily and you can trigger a check from the menu bar or Settings → About. Cutting a
release is one command: bump the version in `project.yml`, then
`./release.sh "notes"` (builds, signs, updates the appcast, tags, and publishes).

## Where things live

| What | Where |
|---|---|
| Dictionary, history, stats | `~/Library/Application Support/WisprFree/` |
| Speech models (Parakeet, Cohere) | `~/Library/Application Support/FluidAudio/` |
| API keys | macOS Keychain |

## Built on the shoulders of

[FluidAudio](https://github.com/FluidInference/FluidAudio) (Parakeet & Cohere CoreML runtimes) · [WhisperKit](https://github.com/argmaxinc/WhisperKit) (Whisper on CoreML) · Google Gemini · and a novelist who got tired of typing.
