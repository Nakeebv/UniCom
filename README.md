# UniCom

**Unified Global Communications** — I speak my language. You speak yours. We understand each other.

UniCom is a multilingual messaging product: every user picks their preferred language once, and
incoming messages — including voice notes — are translated into it, while the original content
stays canonical and one tap away.

_Tagline: One World. Every Language._

## Repository layout

| Path | What it is |
|---|---|
| `unicom_app/` | Flutter app (iOS · Android · Web). Dark-first "Brand Teal" design system, translation-first chat, real mic recording + audio playback, per-recipient language routing. |
| `src/` | Next.js backend + landing (API routes for auth, conversations, messages, translations, media, sync) — the production contract the mobile app will integrate with. |

## Flutter app

See `unicom_app/README.md` for architecture, demo flow and feature details.

Key behaviour implemented client-side:

- **Per-recipient translation** — one canonical message; one translation record per target
  language (groups route to every member's own language, each viewer sees theirs).
- **Voice pipeline** — record → upload → transcribe → translate → synthesize → play, with honest
  states (queued, transcribing, partial, failed-retryable) and labelled original vs translated
  playback.
- **Real microphone capture** (iOS/Android via `record`) with permission states, preview,
  discard/replay/send; graceful labelled fallback on web.
- **Real audio playback** (via `just_audio`) — play/pause, position, seek, speed.
- **Responsive** — bottom nav on phones, navigation rail on wide surfaces, 8-viewport +
  text-scaling test matrix.

## Development

```bash
cd unicom_app
flutter pub get
flutter run            # or: flutter run -d chrome
flutter test           # 46 tests: routing, voice pipeline, responsive matrix
flutter analyze
```

The mobile client currently runs on an in-memory demo backend (`MockBackend`) that simulates the
translation/voice pipeline; wiring to the `src/` API is the next integration step.

## Status

Working code is documented in the app README; simulation-only behaviour (demo translator, seeded
contacts, simulated TTS variants) is clearly labelled in code and UI.
