import 'package:flutter/material.dart';

/// A launch language in the UniCom capability registry.
///
/// Mirrors the server-side registry described in the architecture:
/// per-language STT / MT / TTS / detection support and regional notes.
/// The demo registry mirrors the planned launch matrix.
@immutable
class LanguageInfo {
  const LanguageInfo({
    required this.code,
    required this.name,
    required this.nativeName,
    required this.flag,
    this.mt = true,
    this.stt = true,
    this.tts = true,
    this.detection = true,
    this.note,
  });

  final String code;
  final String name;
  final String nativeName;
  final String flag;

  /// Machine translation support (provider capability).
  final bool mt;

  /// Speech-to-text support.
  final bool stt;

  /// Text-to-speech support.
  final bool tts;

  /// Automatic language detection support.
  final bool detection;
  final String? note;

  bool get translatable => mt;
}

abstract final class LanguageRegistry {
  static const List<LanguageInfo> all = [
    LanguageInfo(
      code: 'en',
      name: 'English',
      nativeName: 'English',
      flag: '🇬🇧',
      note: 'Fully tested across all providers.',
    ),
    LanguageInfo(
      code: 'es',
      name: 'Spanish',
      nativeName: 'Español',
      flag: '🇪🇸',
      note: 'Fully tested across all providers.',
    ),
    LanguageInfo(
      code: 'fr',
      name: 'French',
      nativeName: 'Français',
      flag: '🇫🇷',
      note: 'Fully tested across all providers.',
    ),
    LanguageInfo(
      code: 'pt',
      name: 'Portuguese',
      nativeName: 'Português',
      flag: '🇵🇹',
      note: 'Text translation only in demo scope.',
      stt: false,
    ),
    LanguageInfo(
      code: 'yo',
      name: 'Yoruba',
      nativeName: 'Yorùbá',
      flag: '🇳🇬',
      note: 'Diacritics and dialects quality-tested for launch.',
    ),
    LanguageInfo(
      code: 'ha',
      name: 'Hausa',
      nativeName: 'Hausa',
      flag: '🇳🇬',
      note: 'Western Hausa variant.',
    ),
    LanguageInfo(
      code: 'ig',
      name: 'Igbo',
      nativeName: 'Igbo',
      flag: '🇳🇬',
      note: 'Translation only — speech synthesis pending provider quality.',
      tts: false,
    ),
    LanguageInfo(
      code: 'sw',
      name: 'Swahili',
      nativeName: 'Kiswahili',
      flag: '🇰🇪',
      note: 'Coastal standard variant.',
    ),
    LanguageInfo(
      code: 'ar',
      name: 'Arabic',
      nativeName: 'العربية',
      flag: '🇸🇦',
      note: 'Modern Standard Arabic; RTL layout verified.',
    ),
    LanguageInfo(
      code: 'de',
      name: 'German',
      nativeName: 'Deutsch',
      flag: '🇩🇪',
      note: 'Fully tested across all providers.',
    ),
    LanguageInfo(
      code: 'zh',
      name: 'Chinese',
      nativeName: '中文',
      flag: '🇨🇳',
      note: 'Not enabled in this build — shows graceful fallback.',
      mt: false,
      stt: false,
      tts: false,
      detection: false,
    ),
  ];

  static const LanguageInfo fallback = LanguageInfo(
    code: 'en',
    name: 'English',
    nativeName: 'English',
    flag: '🌐',
  );

  static LanguageInfo? byCode(String? code) {
    for (final l in all) {
      if (l.code == code) return l;
    }
    return null;
  }

  static LanguageInfo of(String? code) => byCode(code) ?? fallback;

  static List<LanguageInfo> get supported =>
      all.where((l) => l.translatable).toList();
}
