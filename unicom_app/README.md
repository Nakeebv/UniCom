# UniCom — Flutter App

**Unified Global Communications.** One World. Every Language.

A multilingual messaging app (Android · iOS · Web) where every user picks a language once, and incoming messages — including voice notes — are translated into it. The original content stays canonical and one tap away. The brand mark is a speech-inspired "U": two speakers, two languages, one conversation.

Built with Flutter + Riverpod (dark-mode-first "Brand Teal" design system, Inter typography).

## Run it

```bash
cd unicom_app
flutter pub get
flutter run                # pick an iOS / Android device or emulator
flutter test               # 47 tests: language routing, voice pipeline, navigation, responsiveness
```

> **Sign in with any email** (e.g. `demo@unicom.app` / any password), or register, verify (any 4-digit code), and pick your language. The demo seeds conversations with contacts speaking Spanish 🇪🇸, Yorùbá 🇳🇬, French 🇫🇷, Hausa 🇳🇬, Arabic 🇸🇦, Portuguese 🇵🇹 and Chinese 🇨🇳 (intentionally demonstrates the graceful "translation unavailable" state). A seeded **Team Align** group has members speaking three different languages.

## What is real vs. simulated

| Capability | Status |
| --- | --- |
| Microphone recording | **Real** on iOS/Android (`record` package): permission flow (denied / permanently-denied → system settings), elapsed time + live input levels, stop → replay → discard/send, cancel-safe cleanup. Web build shows an honest labelled fallback (no mic API). |
| Audio playback | **Real** (`just_audio`): play/pause, position stream, tap-to-seek on the waveform, completion, playback speed, correct disposal. Replay plays the actual recorded file. |
| Recipient-specific translation | **Real routing logic** on the canonical-message model: one message, one translation record per target language; groups create a record per member language; each viewer renders their own. |
| Translated audio variants ("Play in Yorùbá") | **Simulated** (demo): the pipeline marks variants complete per the language registry's TTS capability; playback of a variant is labelled "Translated speech (demo audio)". Swap the TTS adapter for production. |
| Text MT / STT| **Simulated** deterministic offline engine (`DemoTranslator` phrasebook) with per-language capability registry — unsupported pairs show `unavailable` + Retry, never fake success. |
| Messaging transport | **Demo** in-memory backend (`MockBackend`) mirroring the Next.js API contract in `../src/`; no networking in the client yet. |

Seeded demo voice notes without stored media play a generated quiet tone of matching duration so progress/seek/completion behave like real audio — labelled "(demo)".

## Features

- Translation-first chat: translated-by-default incoming bubbles, "Translated to {language} ⇄ Original in {language}" toggle that never mutates the canonical message, pending/processing/completed/unavailable states with retry.
- Voice notes: full pipeline presentation (upload → queued → transcribing → translating → speech → completed/partial/failed-retryable), original + translated transcripts, labelled original vs translated playback from the recipient's actual language preference.
- Auto-translate and auto-play-translated-audio preferences (**auto-play off by default** — UniCom never starts sound unprompted), preferred original-audio-first option, playback speed.
- Familiar messaging UX: delivery receipts (✓/✓✓/read), typing indicators, unread badges, swipe-to-mute/clear, share sheet, polls with live tallies, groups with per-member languages, contacts, call screens, block/report with confirmations.
- Responsive: bottom nav on phones, NavigationRail ≥ 600px, constrained forms/bubble widths, 8-viewport + 2.0× text-scale test coverage.

## Architecture

```
lib/
├── core/
│   ├── theme/         palette.dart (tokens) · theme.dart (Inter, UniColors ext., Layout/breakpoints)
│   └── audio/         recording_service.dart (record pkg + permission flow)
│                      playback_service.dart (just_audio controller)
│                      demo_audio.dart|_io|_stub (conditional WAV source)
├── data/
│   ├── models/        user · conversation · message (text/voice/poll, translations map)
│   │                  language registry (MT/STT/TTS/detect capabilities)
│   └── demo/          avatar_registry (deterministic Unsplash placeholders)
│                      mock_backend.dart (canonical messages, per-recipient
│                      translation jobs, voice pipeline, receipts, groups, polls)
├── features/          splash · onboarding · auth · chats · chat (+widgets:
│                      bubble/voice/waveform/composer/recorder) · contacts ·
│                      calls · groups · profile · settings · shell
└── shared/widgets/    logo (vector speech-U, light/dark/mono) · ui_kit · sheets · kit_scaffold
```

### Swapping demo for production

- `DemoTranslator` → a real `TranslationProvider` adapter (per-pair capability flags stay).
- `_runVoicePipeline` stages → async jobs calling real STT/TTS; translated-audio variants then carry real source keys and the "(demo audio)" labels disappear.
- `MockBackend` → repositories against the Next.js API in `../src/` (auth, conversations, messages, translations, media, sync). UI reads only the ChangeNotifier surface, so screens are unchanged.

No secrets or API keys are embedded in the client.

## Platform notes

- iOS: `NSMicrophoneUsageDescription` configured (real recording).
- Android: `INTERNET`, `RECORD_AUDIO`, `POST_NOTIFICATIONS` declared; launcher icons generated (`flutter_launcher_icons`).
- Web release build verified — recording/playback degrade with explicit labels there.

## Verified

- `flutter analyze` → 0 errors / 0 warnings
- `flutter test` → 46+ tests passing (per-recipient routing yo↔ar, 3-language group fan-out, canonical immutability, pending→completed, unavailable+retry, TTS-partial voice, prefs round-trip, nav↔branch alignment, overflow matrix @ 8 viewports + 2× text scale)
- `flutter build web --release` → ✅
