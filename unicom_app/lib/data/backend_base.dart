import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show ThemeMode;

import 'models/conversation.dart';
import 'models/message.dart';
import 'models/user.dart';

/// Storage-key-vocabulary shared by UI screens about the message/voice model —
/// re-exported for convenience so screens import one file.
export 'models/conversation.dart';
export 'models/message.dart';
export 'models/user.dart';
export 'models/language.dart' show LanguageRegistry, LanguageInfo;

/// Backend contract shared by the demo (MockBackend) and the live API
/// (RemoteBackend). Screens depend only on this surface, so flipping the
/// data source never touches UI code.
///
/// Demo-only behaviors (seeded personas, simulated partner replies, poll
/// votes simulation) stay in the mock implementation; the remote backend is
/// expected to answer with the authoritative server state.
abstract class UniBackend extends ChangeNotifier {
  // ── Session ──────────────────────────────────────────────────────────────
  UserProfile? get me;
  bool get isSignedIn;
  bool get onboarded;
  Future<void> load();
  Future<void> register({required String name, required String username});
  Future<void> signIn(String emailOrUsername);
  Future<void> signOut();

  // ── Directory ────────────────────────────────────────────────────────────
  List<UserProfile> get contacts;
  UserProfile? contactById(String id);
  bool isBlocked(UserProfile user);
  Future<void> blockUser(String userId);
  Future<void> unblockUser(String userId);

  // ── Conversations & messages ────────────────────────────────────────────
  List<Conversation> get conversations;
  Conversation? conversationOf(String id);
  List<Message> messagesOf(String conversationId);
  Message? lastMessageOf(String conversationId);
  int unreadCount(String conversationId);
  int get totalUnread;
  void markRead(String conversationId);
  Conversation openWith(UserProfile other);
  Conversation createConversation(UserProfile other);
  Conversation createGroup(String title, List<String> memberIds);
  void clearConversation(String conversationId);

  void sendMessage(String conversationId, String text, {String? clientKey});
  Message sendVoiceNote(
    String conversationId,
    Duration duration,
    List<double> waveform, {
    String? filePath,
  });
  void resendTranslation(String messageId, String targetLanguage);
  Future<void> retryVoiceSpeech(String messageId);
  void deleteMessage(String messageId);
  bool reportMessage(String messageId, String reason);

  Message createPoll(
    String conversationId,
    String question,
    List<String> options,
  );
  void votePoll(
    String conversationId,
    String messageId,
    int optionIndex, {
    String? voterId,
  });

  /// Live-testing helper: resolves a playable URL for a media asset
  /// (voice note or synthesized speech variant). Mock returns an
  /// already-usuable local path — remote returns a presigned URL.
  Future<String?> mediaAssetUrl(String assetId);

  // ── Preferences ──────────────────────────────────────────────────────────
  ThemeMode get themeMode;
  Future<void> setThemeMode(ThemeMode mode);
  Future<void> setLanguage(String code);
  Future<void> setSpeechLanguage(String code);
  Future<void> setVoice(String voiceId);
  Future<void> updateProfile({String? name, String? username, String? about});
  Future<void> setPrivacyFlag({
    bool? readReceipts,
    bool? lastSeenVisible,
    bool? typingVisible,
    bool? previewVisible,
  });

  bool get autoTranslate;
  Future<void> setAutoTranslate(bool value);
  bool get autoPlayTranslated;
  Future<void> setAutoPlayTranslated(bool value);
  bool get preferOriginalAudio;
  Future<void> setPreferOriginalAudio(bool value);
  double get playbackRate;
  Future<void> setPlaybackRate(double value);

  // ── Demo-only helpers (no-op or local-only on remote) ───────────────────
  void ensureSeeded() {}
  void seedConversations() {}
}
