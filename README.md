# WisprFree

A free, personal Wispr Flow–style dictation app for macOS, built for novel writing.

Speak anywhere — clean, grammatical text is typed into whatever app you're in.
A floating pill at the bottom of the screen shows an animated waveform while recording.

## Hotkeys

| Key | Action |
|---|---|
| **Hold Fn** | Push-to-talk: record while held, release to insert |
| **Fn+Space** | Hands-free recording (release the keys) |
| **Tap Fn** (while recording) | Stop and insert |
| **Esc** (while recording) | Cancel, discard the recording |

> Set System Settings → Keyboard → **"Press 🌐 key to" = Do Nothing**, otherwise
> tapping Fn also opens the emoji picker.

## How it works

1. **Record** — mic audio is captured at 16 kHz while the hotkey is held.
2. **Transcribe** — [Parakeet TDT v3](https://github.com/FluidInference/FluidAudio)
   runs locally on the Apple Neural Engine (free, offline, ~instant).
3. **Clean up** — Gemini (Vertex AI) fixes grammar, removes fillers/false starts and
   pauses, and corrects glossary names (e.g. pinyin names like *Lin Ming*).
4. **Insert** — the result is pasted into the frontmost app (clipboard is restored).

### Modes (Settings → General)

| Mode | What it does |
|---|---|
| Parakeet + Gemini cleanup *(default)* | Local STT, then LLM text cleanup. Fast and nearly free. |
| Audio directly to Gemini | Sends the WAV straight to Gemini — transcription + cleanup in one shot. |
| Parakeet only | Raw local transcript, fully offline, no cleanup. |

If Gemini is unreachable, the raw Parakeet transcript is inserted instead (toggleable),
so a dictation is never lost.

## Dictionary

Settings → Dictionary. Add character/place names ("Lin Ming", "Xiao Yan") with optional
"often misheard as" hints. The glossary is injected into every Gemini request so names
come out spelled correctly.

## Requirements

- Apple Silicon Mac, macOS 14+
- Google Cloud credentials: `gcloud auth application-default login`
  (the app mints Vertex AI tokens from your ADC file; no API key needed)
- Permissions granted on first use: **Microphone** and **Accessibility**
  (needed to type into other apps)

## Build

```sh
brew install xcodegen   # once
./install.sh            # build (Release) + install into /Applications + launch
```

First launch downloads the Parakeet model (~460 MB) to
`~/Library/Application Support/FluidAudio/`.

## Configuration

Settings → Vertex AI: model (default `gemini-3.5-flash-lite`), GCP project, location
(default `global`). Dictionary and history are stored in
`~/Library/Application Support/WisprFree/`.
