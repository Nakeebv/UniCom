import 'package:flutter/material.dart';

import '../../core/theme/palette.dart';
import '../../core/utils.dart';
import 'language.dart';

@immutable
class Presence {
  const Presence({required this.online, this.lastSeen});
  final bool online;
  final DateTime? lastSeen;
}

@immutable
class UserProfile {
  const UserProfile({
    required this.id,
    required this.name,
    required this.username,
    required this.languageCode,
    this.speechLanguageCode,
    this.voiceId,
    this.presence = const Presence(online: false),
    this.about,
    this.readReceipts = true,
    this.lastSeenVisible = true,
    this.typingVisible = true,
    this.previewVisible = true,
    this.colorSeed,
    this.avatarUrl,
  });

  final String id;
  final String name;
  final String username;
  final String languageCode;
  final String? speechLanguageCode;
  final String? voiceId;
  final Presence presence;
  final String? about;
  final bool readReceipts;
  final bool lastSeenVisible;
  final bool typingVisible;
  final bool previewVisible;
  final int? colorSeed;

  /// Real uploaded avatar (network URL). Always takes precedence over the
  /// bundled sample placeholder portrait when present.
  final String? avatarUrl;

  LanguageInfo get language => LanguageRegistry.of(languageCode);
  LanguageInfo get speechLanguage =>
      LanguageRegistry.of(speechLanguageCode ?? languageCode);

  UserProfile copyWith({
    String? name,
    String? username,
    String? languageCode,
    String? speechLanguageCode,
    String? voiceId,
    Presence? presence,
    String? about,
    bool? readReceipts,
    bool? lastSeenVisible,
    bool? typingVisible,
    bool? previewVisible,
    String? avatarUrl,
  }) {
    return UserProfile(
      id: id,
      name: name ?? this.name,
      username: username ?? this.username,
      languageCode: languageCode ?? this.languageCode,
      speechLanguageCode: speechLanguageCode ?? this.speechLanguageCode,
      voiceId: voiceId ?? this.voiceId,
      presence: presence ?? this.presence,
      about: about ?? this.about,
      readReceipts: readReceipts ?? this.readReceipts,
      lastSeenVisible: lastSeenVisible ?? this.lastSeenVisible,
      typingVisible: typingVisible ?? this.typingVisible,
      previewVisible: previewVisible ?? this.previewVisible,
      colorSeed: colorSeed,
      avatarUrl: avatarUrl ?? this.avatarUrl,
    );
  }

  LinearGradient get gradient {
    const List<List<Color>> s = Palette.avatarSpectrum;
    final idx = stableHash(id) % s.length;
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: s[idx],
    );
  }

  String get initials => initialsOf(name);
}
