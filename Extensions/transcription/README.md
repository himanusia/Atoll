# Atoll · Transcription extension

Local meeting transcription for the notch. Records **system audio + microphone**, transcribes
on-device with Whisper (MLX, Apple Silicon), and shows live text — no bot joins the call, no
summarization, nothing leaves the machine.

## What it adds to Atoll

| Surface | Behaviour |
|---|---|
| Notch tab **Transkrip** | REC / STOP button, elapsed clock, live transcript tail, model picker (`large-v3`, `turbo`, `small`) |
| Live Activity | Appears only while recording: waveform icon, `mm:ss` elapsed, word count |
| Control panel | Same UI available at <http://127.0.0.1:8899> for browser / scripting |

## Requirements

- Atoll with third-party extensions enabled (`enableThirdPartyExtensions`, default on)
- Hermes-side engine: `~/.hermes/bin/tx` (recorder `txrec` + `mlx-whisper` venv).
  Override the binary with `TX_BIN=/path/to/tx`.

## Run

```sh
npm install
node host.js
```

Authorize the extension once when Atoll asks (bundle `dev.hima.notch-plugins`); the tab then
persists across launches. Keep it alive with a LaunchAgent if you want it always available.

## How recording works

`host.js` never touches audio itself. It drives the engine:

- `tx start --global --chunk 20` → `txrec` opens a CoreAudio process tap (system audio) plus an
  `AVAudioEngine` mic tap, writing `chunk-NNNN.wav` / `mic-NNNN.wav` every 20 s
- `tx process <dir>` → transcribes finished chunks with `mlx-whisper` (`language=id` by default),
  caching per chunk so live updates stay cheap and skipping near-silent chunks
- `tx stop` → final chunk, merged `transcript.txt` / `.srt` / `.json`

Transcripts land in `~/.hermes/transcripts/<timestamp>/`.

## Notes

- Recording other participants requires their knowledge/consent.
- The engine captures whatever the Mac is playing; use headphones if you do not want the mic to
  re-capture speaker output.
