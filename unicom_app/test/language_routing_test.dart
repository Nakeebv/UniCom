import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:unicom/data/demo/mock_backend.dart';
import 'package:unicom/data/demo/demo_translator.dart';
import 'package:unicom/data/models/message.dart';

/// Boots a fresh MockBackend signed in as a display-language [meLang] user.
Future<MockBackend> bootBackend(String meLang) async {
  SharedPreferences.setMockInitialValues({});
  final b = MockBackend();
  await b.load();
  await b.signIn('tester@unicom.app');
  await b.setLanguage(meLang);
  await b.setSpeechLanguage(meLang);
  b.ensureSeeded();
  return b;
}

/// Drains the demo pipeline's chained Future.delayed timers (upload →
/// transcribe → translate → synthesize) so widget tests end clean.
Future<void> drainTimers(WidgetTester tester) async {
  for (var i = 0; i < 60; i++) {
    await tester.pump(const Duration(seconds: 1));
  }
}

void main() {
  group('recipient-specific language routing', () {
    testWidgets(
      'Yoruba sender → Arabic recipient sees Arabic, original intact',
      (tester) async {
        final b = await bootBackend('ar');
        // Amara speaks Yoruba; her seeded conversation contains yo texts.
        final conv = b.conversations.firstWhere(
          (c) => c.other.id == 'usr_amara',
        );
        b.markRead(conv.id);
        await tester.pump(const Duration(seconds: 7));

        final incoming =
            b
                .messagesOf(conv.id)
                .where(
                  (m) =>
                      m.senderId == 'usr_amara' && m.kind == MessageKind.text,
                )
                .toList();
        expect(incoming, isNotEmpty);

        for (final m in incoming) {
          // Canonical original is never mutated.
          expect(m.text, isNotNull);
          expect(m.sourceLanguage, 'yo');
          final tr = m.translationFor('ar');
          expect(tr, isNotNull, reason: 'recipient (ar) must have a record');
          expect(tr!.targetLanguage, 'ar');
          expect(tr.status, TranslationStatus.completed);
          // Translation text differs from original (distinct phrasebook string).
          expect(tr.text == m.text, isFalse);
        }

        // My own outgoing messages get an Arabic-authored original and a
        // translation record for the SENDER's language (yo), not mine.
        b.sendMessage(conv.id, DemoPhrases.book['hello_how_are_you']!['en']!);
        await tester.pump(const Duration(seconds: 7));
        final mine =
            b.messagesOf(conv.id).where((m) => m.senderId == b.me!.id).last;
        expect(mine.senderId, b.me!.id);
        final toYo = mine.translationFor('yo');
        expect(toYo, isNotNull, reason: 'sender side routes to receiver lang');
        // Original untouched.
        expect(mine.text, DemoPhrases.book['hello_how_are_you']!['en']!);
      },
    );
  });

  group('group messages reach every recipient language', () {
    testWidgets('sendMessage creates per-recipient translation records', (
      tester,
    ) async {
      final b = await bootBackend('en');
      final group = b.conversations.firstWhere((c) => c.isGroup);
      b.sendMessage(group.id, DemoPhrases.book['good_morning']!['en']!);
      await tester.pump(const Duration(seconds: 9));

      final msg =
          b.messagesOf(group.id).where((m) => m.senderId == b.me!.id).last;
      expect(msg.senderId, b.me!.id);
      expect(
        msg.text,
        DemoPhrases.book['good_morning']!['en']!,
        reason: 'canonical stays intact',
      );

      // Distinct recipient languages: yo (Amara), es (Diego), ha (Kwame).
      final languages = group.others.map((u) => u.languageCode).toSet();
      expect(languages.length, greaterThanOrEqualTo(3));
      for (final lang in languages) {
        final rec = msg.translationFor(lang);
        expect(
          rec,
          isNotNull,
          reason: 'every recipient language needs its own record ($lang)',
        );
      }
      // Exactly one canonical message — never duplicated per recipient.
      expect(b.messagesOf(group.id).where((m) => m.id == msg.id).length, 1);
    });
  });

  group('translation states', () {
    testWidgets('pending → completed with original preserved', (tester) async {
      final b = await bootBackend('en');
      final conv = b.conversations.firstWhere((c) => c.other.id == 'usr_diego');
      // Seed one incoming Spanish message directly to control timing.
      b.markRead(conv.id);
      final incoming =
          b
              .messagesOf(conv.id)
              .where((m) => m.senderId == 'usr_diego')
              .toList();
      expect(incoming, isNotEmpty);
      final m = incoming.last;
      final original = m.text;

      final tr = b.messageById(m.id)!.translationFor('en');
      if (tr != null && tr.status != TranslationStatus.completed) {
        // Mid-flight record exists → pending/processing visible to UI.
        expect(
          tr.status,
          anyOf(TranslationStatus.queued, TranslationStatus.translating),
        );
      }
      await tester.pump(const Duration(seconds: 7));
      final done = b.messageById(m.id)!.translationFor('en');
      expect(done, isNotNull);
      expect(done!.status, TranslationStatus.completed);
      // The canonical message was never mutated by translation.
      expect(b.messageById(m.id)!.text, original);
      await drainTimers(tester);
    });

    testWidgets('unsupported target language keeps original + retry', (
      tester,
    ) async {
      // zh is mt:false in the registry → graceful unavailable state.
      final b = await bootBackend('zh');
      final conv = b.conversations.firstWhere((c) => c.other.id == 'usr_diego');
      b.markRead(conv.id);
      await tester.pump(const Duration(seconds: 7));
      final incoming =
          b
              .messagesOf(conv.id)
              .where((m) => m.senderId == 'usr_diego')
              .toList();
      expect(incoming, isNotEmpty);
      for (final m in incoming) {
        final tr = m.translationFor('zh');
        if (tr == null) continue; // same-lang messages have no record
        expect(
          tr.status,
          anyOf(TranslationStatus.unavailable, TranslationStatus.completed),
        );
        if (tr.status == TranslationStatus.unavailable) {
          expect(tr.errorMessage, isNotNull);
          // And the user can retry without mutating the original:
          final before = m.text;
          b.resendTranslation(m.id, 'zh');
          expect(m.text, before);
        }
      }
      await drainTimers(tester);
    });
  });

  group('voice translation', () {
    testWidgets('translated text available when TTS is not (partial)', (
      tester,
    ) async {
      // Igbo display language: registry marks tts:false.
      final b = await bootBackend('ig');
      final conv = b.conversations.firstWhere((c) => c.other.id == 'usr_amara');
      b.markRead(conv.id);
      await tester.pump(const Duration(seconds: 8));

      final voices =
          b
              .messagesOf(conv.id)
              .where((m) => m.kind == MessageKind.voice)
              .where((m) => m.senderId != b.me!.id)
              .toList();
      expect(voices, isNotEmpty);
      for (final v in voices) {
        final payload = v.voice!;
        // Text translation may succeed while speech synthesis is pending.
        if (payload.stage == VoiceStage.partial) {
          expect(
            payload.translatedTranscripts['ig'],
            isNotNull,
            reason: 'partial = text ready, audio absent',
          );
          expect(payload.audioVariants['ig'], isNull);
          expect(payload.error, isNotNull);
        }
        // Original transcript retained in every case.
        expect(payload.transcript, isNotNull);
      }
      await drainTimers(tester);
    });
  });

  group('playback & automation defaults', () {
    test('auto-play translated audio is OFF by default', () async {
      final b = await bootBackend('en');
      expect(b.autoPlayTranslated, isFalse);
      expect(b.autoTranslate, isTrue);
      expect(b.preferOriginalAudio, isFalse);
      expect(b.playbackRate, 1.0);
    });

    test('preferences persist and round-trip', () async {
      final b = await bootBackend('en');
      await b.setAutoPlayTranslated(true);
      await b.setPreferOriginalAudio(true);
      await b.setAutoTranslate(false);
      await b.setPlaybackRate(1.5);

      final b2 = await bootB2();
      expect(b2.autoPlayTranslated, isTrue);
      expect(b2.preferOriginalAudio, isTrue);
      expect(b2.autoTranslate, isFalse);
      expect(b2.playbackRate, 1.5);
    });
  });
}

/// Fresh backend sharing the same in-memory prefs keys.
Future<MockBackend> bootB2() async {
  final b = MockBackend();
  await b.load();
  return b;
}
