import 'dart:math';

import 'package:flutter/material.dart';

import '../../core/utils.dart';

/// Message kinds supported by the MVP.
enum MessageKind { text, voice, poll, system }

/// Server-side delivery lifecycle rendered in outgoing bubbles.
enum MessageDelivery { sending, sent, delivered, read, failed }

/// Translation record status — mirrors `message_translations.status`.
enum TranslationStatus { none, queued, translating, completed, unavailable }

/// A per-target-language translation. The original message remains intact;
/// translations are separate, versioned assets.
@immutable
class Translation {
  const Translation({
    required this.targetLanguage,
    required this.status,
    this.text,
    this.provider = 'demo-translation-provider',
    this.errorMessage,
  });

  final String targetLanguage;
  final TranslationStatus status;
  final String? text;
  final String provider;
  final String? errorMessage;

  Translation copyWith({
    TranslationStatus? status,
    String? text,
    String? errorMessage,
  }) {
    return Translation(
      targetLanguage: targetLanguage,
      status: status ?? this.status,
      text: text ?? this.text,
      provider: provider,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  Map<String, dynamic> toMap() => {
    'message_id': targetLanguage,
    'target_language': targetLanguage,
    'translated_text': text,
    'status': status.name,
    'provider': provider,
  };
}

/// Voice-processing job states (explicit, per architecture):
/// uploaded → queued → transcribing → translating → synthesizing → completed
enum VoiceStage {
  recorded,
  uploading,
  queued,
  transcribing,
  translating,
  synthesizing,
  completed,

  /// transcript / translation available, but generated speech is not.
  partial,
  failedRetryable,
  failedPermanent,
  cancelled,
}

extension VoiceStageX on VoiceStage {
  bool get isTerminal =>
      this == VoiceStage.completed ||
      this == VoiceStage.partial ||
      this == VoiceStage.failedPermanent;

  String get label => switch (this) {
    VoiceStage.recorded => 'Recorded',
    VoiceStage.uploading => 'Uploading',
    VoiceStage.queued => 'Queued',
    VoiceStage.transcribing => 'Transcribing',
    VoiceStage.translating => 'Translating',
    VoiceStage.synthesizing => 'Generating speech',
    VoiceStage.completed => 'Ready',
    VoiceStage.partial => 'Partial — no audio',
    VoiceStage.failedRetryable => 'Retrying…',
    VoiceStage.failedPermanent => 'Failed',
    VoiceStage.cancelled => 'Cancelled',
  };

  bool get isBusy =>
      this == VoiceStage.uploading ||
      this == VoiceStage.queued ||
      this == VoiceStage.transcribing ||
      this == VoiceStage.translating ||
      this == VoiceStage.synthesizing ||
      this == VoiceStage.failedRetryable;
}

@immutable
class VoicePayload {
  const VoicePayload({
    required this.jobId,
    required this.duration,
    required this.waveform,
    required this.stage,
    this.transcript,
    this.detectedLanguage,
    this.translatedTranscripts = const {},
    this.audioVariants = const {},
    this.error,
    this.storageKey,
    this.recordedFilePath,
  });

  final String jobId;
  final Duration duration;
  final List<double> waveform;
  final VoiceStage stage;
  final String? transcript;
  final String? detectedLanguage;

  /// target_language → translated transcript text.
  final Map<String, String> translatedTranscripts;

  /// target_language → synthesized variant key (demo stand-in for audio).
  final Map<String, bool> audioVariants;
  final String? error;
  final String? storageKey;

  /// Local path of genuinely recorded audio (mobile mic capture). When
  /// present, playback plays this real file instead of demo audio.
  final String? recordedFilePath;

  VoicePayload copyWith({
    VoiceStage? stage,
    String? transcript,
    String? detectedLanguage,
    Map<String, String>? translatedTranscripts,
    Map<String, bool>? audioVariants,
    String? error,
  }) {
    return VoicePayload(
      jobId: jobId,
      duration: duration,
      waveform: waveform,
      stage: stage ?? this.stage,
      transcript: transcript ?? this.transcript,
      detectedLanguage: detectedLanguage ?? this.detectedLanguage,
      translatedTranscripts:
          translatedTranscripts ?? this.translatedTranscripts,
      audioVariants: audioVariants ?? this.audioVariants,
      error: error ?? this.error,
      storageKey: storageKey,
    );
  }
}

/// An in-chat poll (`polls` + `poll_votes`). Votes track voter ids per
/// option so the bubble can re-render tallies live and show my choice.
@immutable
class PollPayload {
  const PollPayload({
    required this.question,
    required this.options,
    this.votes = const {},
    this.myVote,
    this.closed = false,
  });

  final String question;
  final List<String> options;

  /// optionIndex → voter user ids.
  final Map<int, List<String>> votes;
  final int? myVote;
  final bool closed;

  int totalVotes(List<String> memberIds) {
    var n = 0;
    for (final list in votes.values) {
      n += list.where(memberIds.contains).length;
    }
    return n;
  }

  PollPayload copyWith({
    Map<int, List<String>>? votes,
    int? myVote,
    bool? closed,
  }) {
    return PollPayload(
      question: question,
      options: options,
      votes: votes ?? this.votes,
      myVote: myVote ?? this.myVote,
      closed: closed ?? this.closed,
    );
  }
}

/// The canonical message record. One row per message — never one per
/// recipient-language.
@immutable
class Message {
  const Message({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.kind,
    required this.createdAt,
    this.text,
    this.sourceLanguage,
    this.clientKey,
    this.delivery = MessageDelivery.sending,
    this.translations = const {},
    this.voice,
    this.poll,
    this.deleted = false,
    this.editedAt,
    this.sourceVersion = 1,
  });

  final String id;
  final String conversationId;
  final String senderId;
  final MessageKind kind;
  final DateTime createdAt;

  /// `message_contents.original_text`
  final String? text;
  final String? sourceLanguage;
  final String? clientKey;
  final MessageDelivery delivery;
  final Map<String, Translation> translations;
  final VoicePayload? voice;

  /// Present when [kind] is [MessageKind.poll].
  final PollPayload? poll;
  final bool deleted;
  final DateTime? editedAt;
  final int sourceVersion;

  String get stableKey => clientKey ?? id;

  /// Translation for a target language, if any.
  Translation? translationFor(String lang) => translations[lang];

  Message copyWith({
    String? text,
    MessageDelivery? delivery,
    Map<String, Translation>? translations,
    VoicePayload? voice,
    PollPayload? poll,
    bool? deleted,
    DateTime? editedAt,
  }) {
    return Message(
      id: id,
      conversationId: conversationId,
      senderId: senderId,
      kind: kind,
      createdAt: createdAt,
      text: text ?? this.text,
      sourceLanguage: sourceLanguage,
      clientKey: clientKey,
      delivery: delivery ?? this.delivery,
      translations: translations ?? this.translations,
      voice: voice ?? this.voice,
      poll: poll ?? this.poll,
      deleted: deleted ?? this.deleted,
      editedAt: editedAt ?? this.editedAt,
      sourceVersion: sourceVersion,
    );
  }

  /// Deterministic waveform for seeded demo voice notes (or live capture).
  static List<double> seededWaveform(String seed, [int n = 44]) {
    final rnd = Random(stableHash(seed));
    return List.generate(n, (i) {
      final envelope = 0.45 + 0.55 * sin(i / n * pi).abs();
      return (0.18 + rnd.nextDouble() * 0.82 * envelope).clamp(0.08, 1.0);
    });
  }
}
