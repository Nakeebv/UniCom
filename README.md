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

### Backend (live API)

```bash
cp .env.example .env      # add R2 / Groq / Cloudflare AI keys — every feature is env-gated
npm install
npx drizzle-kit generate  # emits SQL into drizzle/ (schema changes)
psql "$DATABASE_URL" -f drizzle/0000_hot_hardball.sql   # apply (or drizzle-kit push in a TTY)
npm run dev               # Next.js API on http://localhost:3000
./scripts/smoke.sh        # register → converse → translations → voice pipeline
```

> **Use a dedicated database** (e.g. `unicom`) — `app_db` environments that
> already contain other projects will collide on table names like `messages`.

Verified live configuration (2026-10): Whisper STT transcribes real speech;
Groq `openai/gpt-oss-20b` LLM translation; MeloTTS generates Spanish speech
variants stored in R2; playback via presigned URLs.

**R2 CORS** (browser-preview audio only; mobile exempt) — the object-scope
token cannot edit bucket config, so set it once in Dashboard → R2 →
`unicom-media` → Settings → CORS policy:

```json
[{"AllowedOrigins":["*"],"AllowedMethods":["GET","PUT","HEAD"],"AllowedHeaders":["*"],"MaxAgeSeconds":3600}]
```

### Flutter app — demo mode (default, zero config)

```bash
cd unicom_app
flutter pub get
flutter run            # or: flutter run -d chrome
flutter test           # 46 tests: routing, voice pipeline, responsive matrix
flutter analyze
```

Runs on the in-memory demo backend (`MockBackend`) that simulates MT/STT/TTS.

### Flutter app — LIVE mode (real API)

```bash
# Android emulator (10.0.2.2 = host loopback). Use LAN IP on physical devices.
flutter run --dart-define=UNICOM_BASE_URL=http://10.0.2.2:3000
```

In live mode: real register/login (cookie session), real conversations and
messages, per-recipient translations from the server, **actual recorded m4a
uploads** to the API (R2 when configured) and playback via short-lived
presigned URLs. Voice notes recorded with the mic go through the real
pipeline: Whisper transcribes → per-recipient MT → MeloTTS speaks the
translation when the target language is covered.

#### What activates with which key (`backend/.env`)

| Key | Enables |
| --- | --- |
| `GROQ_API_KEY` | High-quality LLM translation (prepended to the free chain) + alternate STT |
| `CLOUDFLARE_ACCOUNT_ID` + `CLOUDFLARE_AI_API_TOKEN` | Whisper STT + MeloTTS translated speech |
| `R2_*` (4 values) | Private object storage for voice notes/avatars (demo falls back to Postgres bytes) |

No STT provider configured → voice jobs report `failed_retryable` with an
honest message (original audio stays playable) — never fake success.

#### Known gaps in live mode (documented, intentional)
- WebSockets: client polls `/api/sync` (1.2s summaries, 2.5s focused-chat) — the documented WS upgrade is pending.
- Polls are demo-mode only (no API contract yet).
- Avatar upload UI ships with the endpoint; wiring the settings picker is a fast-follow.

## Status

Working code is documented in the app README; simulation-only behaviour (demo translator, seeded
contacts, simulated TTS variants) is clearly labelled in code and UI.
