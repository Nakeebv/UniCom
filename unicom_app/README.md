# UniCom — Flutter App

**Unified Global Communications.** A multilingual messaging app (Android · iOS · Web) where every user picks a language once and UniCom automatically translates incoming messages and voice notes into it — with the original always one tap away.

Built with Flutter + Riverpod, mirroring the UniCom architecture doc: modular features, an explicit translation/voice pipeline with graceful fallbacks, and provider-agnostic AI adapters.

## Run it

```bash
cd unicom_app
flutter pub get
flutter run                # pick an iOS / Android device or emulator
```

Everything runs **fully offline**: translation, speech-to-text, and speech synthesis are simulated by a deterministic demo engine so the complete product experience is visible without servers or API keys.

> **Sign in with any email** — or register, verify (any code), and pick your language. The demo seeds conversations with contacts speaking Spanish 🇪🇸, Yorùbá 🇳🇬, French 🇫🇷, Hausa 🇳🇬, Arabic 🇸🇦, Portuguese 🇵🇹 and Chinese 🇨🇳 (the last one intentionally demonstrates the graceful “translation unavailable” state).

## What to try

| Feature | Where |
| --- | --- |
| Automatic message translation with live “Translating…” shimmer | Open any chat, send a message |
| Original ⇄ translated toggle | Any incoming bubble’s pill toggle |
| Voice-note pipeline (upload → STT → MT → TTS) with animated stepper | 🎙 mic in the composer |
| Transcribed + translated voice playback variants | Amara’s chat (seeded voice note) |
| Partial-state handling (text ready, audio unavailable) + retry | Élodie / voice settings without TTS |
| Language capability registry (MT / STT / TTS / detect) | Settings → Language |
| Read receipts (✓ sent / ✓✓ delivered / read), typing, unread badges | Chat list + bubbles |
| Privacy model disclosure, block & report | Chat long-press / Settings → Privacy |
| Light / dark / system themes | Settings → Appearance |

## Architecture map

```
lib/
├── core/            design tokens, theme (Sora+Inter), utils
├── data/
│   ├── models/      User, Conversation, Message, Translation, VoicePayload,
│   │                Language registry (capabilities per language)
│   └── demo/        DemoTranslator (offline phrasebook MT),
│                    MockBackend (API + BullMQ-worker stand-in):
│                    idempotent sends, delivery receipts, translation jobs
│                    with retry/unavailable states, voice pipeline state
│                    machine, simulated typing & replies
├── features/        splash · onboarding · auth · chats · chat (+ widgets) ·
│                    friends · calls (roadmap) · settings
└── shared/widgets/  ui kit (avatar, chips, buttons, shimmer, sheets…)
```

### Swapping the demo for real providers

The architecture doc’s provider contracts map 1:1 onto the demo:

- `DemoTranslator.translate/detect` → implement `TranslationProvider` with a real MT vendor adapter.
- `_runVoicePipeline` stages → BullMQ jobs calling `SpeechToTextProvider` / `TextToSpeechProvider`.
- `MockBackend` screens touch nothing but its ChangeNotifier surface → replace with real repositories (NestJS `/api/v1`) without UI changes.

 secrecy: no secrets or keys are needed or embedded; the demo is 100% local.

## Platform notes

- iOS: `NSMicrophoneUsageDescription` already configured for when real recording is wired.
- Android: `INTERNET`, `RECORD_AUDIO`, `POST_NOTIFICATIONS` declared in the main manifest.
- Web build verified (`flutter build web`) — app also runs in a browser for quick previews.

## Verified

- `flutter analyze` → **No issues found**
- `flutter test` → **All tests passed**
- `flutter build web --release` → ✅ built
