import 'package:collection/collection.dart';

import 'dart:async';

import 'package:flutter/material.dart' show ThemeMode;
import 'package:shared_preferences/shared_preferences.dart';

import '../backend_base.dart';
import '../models/conversation.dart';
import '../models/message.dart';
import '../models/user.dart';
import 'uni_session.dart';
import 'unicom_api.dart';

/// Live backend against the UniCom Next.js API (cookie session).
///
/// Mirrors the surface screens already use from [MockBackend]; the sync loop
/// polls `/api/sync` (summaries, receipts, presence, typing) and the focused
/// conversation endpoint refreshes translation/voice-job states.
///
/// Honest scope: polls use a 1.2s summary cadence + 2.5s message cadence —
/// WebSockets are the documented production upgrade. Message history is
/// capped at the API's recent-80 window per conversation.
class RemoteBackend extends UniBackend {
  final Map<String, bool> _hasMore = {};
  RemoteBackend({required String baseUrl})
    : api = UniComApi(UniSession(baseUrl: baseUrl));

  late final UniSession session = api.session;
  final UniComApi api;

  static const syncInterval = Duration(milliseconds: 1200);
  static const messageInterval = Duration(milliseconds: 2500);

  UserProfile? _me;
  List<UserProfile> _contacts = [];
  final Map<String, Conversation> _conversations = {};
  final Map<String, Map<String, Message>> _messages = {};
  final Map<String, Set<String>> _typers = {};
  final Map<String, int> _unread = {};
  String? _activeConversation;
  Timer? _syncTimer;
  Timer? _messageTimer;
  StreamSubscription<Map<String, dynamic>>? _eventsSub;
  bool _eventsConnected = false;
  bool _disposed = false;

  // Local-only preference state (UI parity with demo mode).
  ThemeMode _themeMode = ThemeMode.dark;
  SharedPreferences? _prefs;
  final Set<String> _blockedIds = {};

  // ── Lifecycle ────────────────────────────────────────────────────────────

  @override
  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    _themeMode = ThemeMode.values[_prefs!.getInt('ui.themeMode') ?? 1]; // dark
    _blockedIds.addAll(_prefs!.getStringList('safety.blocked') ?? []);
    try {
      _me = _mapMe(await api.me() ?? <String, dynamic>{});
    } on ApiError catch (e) {
      if (!e.unauthorized) rethrow;
      _me = null;
    }

    if (_me == null) return;

    _prefLanguage = _prefs!.getString('pref.language');
    _autoTranslate = _prefs!.getBool('pref.autoTranslate') ?? true;
    _autoPlayTranslated = _prefs!.getBool('pref.autoPlayTranslated') ?? false;
    _preferOriginalAudio = _prefs!.getBool('pref.preferOriginalAudio') ?? false;
    _playbackRate = _prefs!.getDouble('pref.playbackRate') ?? 1.0;

    await _refreshDirectory();
    await _refreshSummaries();
    _startTimers();
    ready = true;
    notifyListeners();
  }

  void _startTimers() {
    _syncTimer?.cancel();
    _messageTimer?.cancel();
    // Polling is now the FALLBACK. With a live SSE connection it runs slow
    // (safety net); without one it runs at the original cadence.
    _syncTimer = Timer.periodic(
      _eventsConnected ? const Duration(seconds: 10) : syncInterval,
      (_) => _safeSync(),
    );
    _messageTimer = Timer.periodic(
      _eventsConnected ? const Duration(seconds: 15) : messageInterval,
      (_) => _safeMessageRefresh(),
    );
    _startEvents();
  }

  /// Live Server-Sent Events stream — the primary realtime channel.
  void _startEvents() {
    _eventsSub?.cancel();
    _eventsSub = session
        .events('/api/realtime')
        .listen(
          (event) {
            _eventsConnected = true;
            _handleEvent(event);
          },
          onError: (_) {
            _eventsConnected = false;
          },
          onDone: () {
            _eventsConnected = false;
          },
          cancelOnError: false,
        );
  }

  void _handleEvent(Map<String, dynamic> event) {
    final kind = event['kind'] as String?;
    final conversationId = event['conversationId'] as String?;
    switch (kind) {
      case 'ping':
        _eventsConnected = true;
        break;
      case 'message':
        if (conversationId != null) {
          unawaited(
            fetchChanged(
              conversationId,
            ).then((_) => _refreshSummaries()).catchError((_) {}),
          );
        }
        break;
      case 'translation':
      case 'voice':
      case 'receipt':
        if (conversationId != null && conversationId == _activeConversation) {
          unawaited(fetchChanged(conversationId).catchError((_) {}));
        }
        break;
      case 'typing':
        if (conversationId != null && event['userId'] != _me?.id) {
          final t =
              (_typers[conversationId] ?? <String>{})
                ..add(event['userId'] as String);
          _typers[conversationId] = t;
          final conv = _conversations[conversationId];
          if (conv != null) {
            _conversations[conversationId] = conv.copyWith(typingUserIds: t);
          }
          notifyListeners();
        }
        break;
      case 'call':
        // Call lifecycle events land here once the calling client ships.
        break;
    }
  }

  /// Heartbeat so the peer sees a live typing indicator (debounced by caller).
  void notifyTyping() {
    final cid = _activeConversation;
    if (cid == null) return;
    unawaited(api.typing(cid).catchError((_) {}));
  }

  Future<void> _safeSync() async {
    if (_me == null || _disposed) return;
    try {
      await _refreshSummaries();
      if (_activeConversation != null) {
        await _fetchTypers(_activeConversation!);
      }
      notifyListeners();
    } on ApiError catch (e) {
      if (e.unauthorized) {
        stopTimers();
        _me = null;
        notifyListeners();
      }
    } catch (_) {
      /* transient network — next tick retried */
    }
  }

  Future<void> _safeMessageRefresh() async {
    if (_me == null || _disposed || _activeConversation == null) return;
    try {
      await fetchChanged(_activeConversation!);
    } catch (_) {}
  }

  /// Cheap incremental refresh: server diff since the newest stored message.
  Future<void> fetchChanged(String conversationId) async {
    final myLang = _me?.languageCode ?? 'en';
    final myId = _me?.id;
    if (myId == null) return;
    final since =
        messagesOf(conversationId)
            .lastWhereOrNull((m) => m.id.startsWith('msg_'))
            ?.createdAt
            .toUtc()
            .toIso8601String();
    final data = await session.get('/api/sync', {
      'conversationId': conversationId,
      if (since != null) 'since': since,
    });
    final list =
        ((data['messages'] ?? const []) as List)
            .whereType<Map<String, dynamic>>();
    final map = _messages.putIfAbsent(conversationId, () => {});
    var changed = false;
    for (final v in list) {
      final mapped = _mapMessage(v, myLang, myId);
      if (mapped.text?.isNotEmpty == true || mapped.kind == MessageKind.voice) {
        map[mapped.id] = mapped;
        changed = true;
      }
      final ck = mapped.clientKey;
      if (ck != null && map.remove('local-$ck') != null) changed = true;
    }
    if (changed) notifyListeners();
  }

  /// Loads one older page (scroll-to-top pagination).
  Future<void> loadOlderMessages(String conversationId) async {
    if (_hasMore[conversationId] == false) return;
    final myLang = _me?.languageCode ?? 'en';
    final myId = _me?.id;
    if (myId == null) return;
    final existing =
        messagesOf(
          conversationId,
        ).where((m) => m.id.startsWith('msg_')).toList();
    if (existing.isEmpty) return;
    final before = existing.first.createdAt.toUtc().toIso8601String();
    final data = await api.messagesBefore(conversationId, before);
    final list =
        ((data['messages'] ?? const []) as List)
            .whereType<Map<String, dynamic>>();
    final map = _messages.putIfAbsent(conversationId, () => {});
    for (final v in list) {
      final mapped = _mapMessage(v, myLang, myId);
      if (map[mapped.id] == null) map[mapped.id] = mapped;
    }
    _hasMore[conversationId] = (data['has_more'] ?? false) as bool;
    notifyListeners();
  }

  bool hasMoreMessages(String conversationId) =>
      _hasMore[conversationId] ?? true;

  void setActiveConversation(String? conversationId) {
    _activeConversation = conversationId;
    if (conversationId != null) {
      unawaited(fetchMessages(conversationId));
    }
  }

  void stopTimers() {
    _syncTimer?.cancel();
    _messageTimer?.cancel();
    _eventsSub?.cancel();
    _syncTimer = null;
    _messageTimer = null;
    _eventsSub = null;
    _eventsConnected = false;
  }

  @override
  void dispose() {
    _disposed = true;
    stopTimers();
    session.dispose();
    super.dispose();
  }

  // ── Mapping helpers ──────────────────────────────────────────────────────

  UserProfile _mapMe(Map<String, dynamic> m) {
    return UserProfile(
      id: (m['id'] ?? '') as String,
      name: (m['displayName'] ?? 'You') as String,
      username: (m['username'] ?? 'you') as String,
      languageCode: (m['preferredLanguage'] ?? 'en') as String,
      speechLanguageCode: m['speechLanguage'] as String?,
      voiceId: m['voiceId'] as String?,
      about: m['bio'] as String?,
      presence: const Presence(online: true),
      avatarUrl: m['avatarUrl'] as String?,
    ).withAbsoluteAvatar(session.baseUrl);
  }

  UserProfile _mapContact(Map<String, dynamic> c) {
    return UserProfile(
      id: (c['id'] ?? '') as String,
      name: (c['displayName'] ?? 'Unknown') as String,
      username: (c['username'] ?? '') as String,
      languageCode: (c['preferredLanguage'] ?? 'en') as String,
      about: c['bio'] as String?,
      presence: Presence(
        online: (c['online'] ?? false) as bool,
        lastSeen:
            c['lastSeenAt'] == null
                ? null
                : DateTime.tryParse(c['lastSeenAt'] as String),
      ),
      avatarUrl: c['avatar_url'] as String?,
    ).withAbsoluteAvatar(session.baseUrl);
  }

  Message _mapMessage(Map<String, dynamic> v, String myLang, String myId) {
    final kind = v['type'] == 'voice' ? MessageKind.voice : MessageKind.text;
    final viewer = (v['viewer'] ?? {}) as Map<String, dynamic>;
    final translation =
        (viewer['translation'] ?? null) as Map<String, dynamic>?;
    final job = (viewer['voiceJob'] ?? null) as Map<String, dynamic>?;
    final media = (v['media'] ?? null) as Map<String, dynamic>?;
    final receipts = (v['receipts'] ?? {}) as Map<String, dynamic>;
    final status = ((translation?['status']) ?? '') as String;
    final mine = v['senderId'] == myId;

    Map<String, Translation>? translations;
    final trText = translation?['text'] as String?;
    if (!mine &&
        !viewerSameLang(viewer, v) &&
        trText != null &&
        trText.isNotEmpty) {
      final mapped = switch (status) {
        'completed' => TranslationStatus.completed,
        'queued' => TranslationStatus.queued,
        'processing' => TranslationStatus.translating,
        'failed' => TranslationStatus.unavailable,
        'stale' => TranslationStatus.unavailable,
        _ => TranslationStatus.none,
      };
      translations = {
        myLang: Translation(
          targetLanguage: myLang,
          status: mapped,
          text: mapped == TranslationStatus.completed ? trText : null,
          provider: (translation?['provider'] ?? '') as String,
          errorMessage:
              mapped == TranslationStatus.unavailable
                  ? 'Server could not translate this message.'
                  : null,
        ),
      };
    }

    final stage = switch ((job?['status'] ?? '') as String) {
      'uploaded' || 'queued' => VoiceStage.queued,
      'transcribing' => VoiceStage.transcribing,
      'translating' => VoiceStage.translating,
      'synthesizing' => VoiceStage.synthesizing,
      'completed' => VoiceStage.completed,
      'partial' => VoiceStage.partial,
      'failed_retryable' => VoiceStage.failedRetryable,
      'failed_permanent' => VoiceStage.failedPermanent,
      'cancelled' => VoiceStage.cancelled,
      _ => VoiceStage.recorded,
    };

    VoicePayload? voice;
    if (kind == MessageKind.voice) {
      final durationMs = (media?['durationMs'] ?? 0) as int;
      final speechAssetId = job?['speech_media_id'] as String?;
      voice = VoicePayload(
        jobId: (v['id'] ?? '') as String,
        duration: Duration(milliseconds: durationMs),
        waveform: waveformForSeed((v['id'] ?? 'wave') as String),
        stage: stage,
        transcript: (v['originalText'] ?? '') as String,
        detectedLanguage: (v['sourceLanguage'] ?? '') as String,
        translatedTranscripts:
            (translations?[myLang]?.status == TranslationStatus.completed &&
                    trText != null)
                ? {myLang: trText}
                : const {},
        audioVariants: {if (speechAssetId != null) myLang: true},
        storageKey: media?['id'] as String?,
        mediaAssetId: media?['id'] as String?,
        speechAssetId: speechAssetId,
      );
    }

    final delivered = (receipts['delivered'] ?? 0) as int;
    final readCount = (receipts['read'] ?? 0) as int;
    final delivery =
        !mine
            ? MessageDelivery.delivered
            : readCount > 0
            ? MessageDelivery.read
            : delivered > 0
            ? MessageDelivery.delivered
            : MessageDelivery.sent;

    return Message(
      id: (v['id'] ?? '') as String,
      conversationId: (v['conversationId'] ?? '') as String,
      senderId: (v['senderId'] ?? '') as String,
      kind: kind,
      text: (v['originalText'] ?? '') as String,
      sourceLanguage: (v['sourceLanguage'] ?? '') as String,
      clientKey: v['clientId'] as String?,
      createdAt:
          DateTime.tryParse((v['createdAt'] ?? '') as String) ?? DateTime.now(),
      delivery: delivery,
      translations: translations ?? const {},
      voice: voice,
      deleted: (v['deleted'] ?? false) as bool,
    );
  }

  bool viewerSameLang(Map<String, dynamic> viewer, Map<String, dynamic> v) =>
      (viewer['sameAsSource'] ?? false) as bool;

  // ── Session (UniBackend) ─────────────────────────────────────────────────

  @override
  UserProfile? get me => _me;

  @override
  bool get isSignedIn => _me != null;

  String? _prefLanguage;
  bool _autoTranslate = true;
  bool _autoPlayTranslated = false;
  bool _preferOriginalAudio = false;
  double _playbackRate = 1.0;

  @override
  bool get onboarded => _me != null && (_prefLanguage?.isNotEmpty ?? false);

  /// One shared demo credential for app-managed accounts. It MUST be a
  /// constant (never `String.hashCode`): Dart hashing differs between the web
  /// and native runtimes and across launches, which previously made login
  /// never match what register stored.
  static const _demoPassword = 'unicom-live-demo';

  /// Same normalization register and login share, so a username entered
  /// either way resolves to the identical account. Mirrors the server rules
  /// (lowercase a–z0–9_, 3–24 chars).
  String _normalizeUsername(String raw) {
    final cleaned = raw
        .split('@')
        .first
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9_]'), '');
    final padded = cleaned.padRight(3, '0');
    return padded.length > 24 ? padded.substring(0, 24) : padded;
  }

  @override
  Future<void> register({
    required String name,
    required String username,
    String? password,
  }) async {
    await api.register(
      username: _normalizeUsername(username),
      displayName: name,
      password:
          (password != null && password.length >= 8) ? password : _demoPassword,
      preferredLanguage: 'en',
    );
    _me = _mapMe(await api.me() ?? <String, dynamic>{});
    notifyListeners();
  }

  @override
  Future<void> signIn(String emailOrUsername, {String? password}) async {
    await api.login(
      username: _normalizeUsername(emailOrUsername),
      password:
          (password != null && password.isNotEmpty) ? password : _demoPassword,
    );
    _me = _mapMe(await api.me() ?? <String, dynamic>{});
    await _refreshDirectory();
    await _refreshSummaries();
    _startTimers();
    ready = true;
    notifyListeners();
  }

  /// Real password sign-in (used by the login screen's live mode).
  Future<void> signInWithPassword({
    required String username,
    required String password,
  }) async {
    await api.login(username: username.toLowerCase(), password: password);
    _me = _mapMe(await api.me() ?? <String, dynamic>{});
    await _refreshDirectory();
    await _refreshSummaries();
    _startTimers();
    notifyListeners();
  }

  @override
  Future<void> signOut() async {
    await api.logout();
    _me = null;
    _conversations.clear();
    _messages.clear();
    _contacts = [];
    stopTimers();
    notifyListeners();
  }

  // ── Directory ────────────────────────────────────────────────────────────

  @override
  List<UserProfile> get contacts => _contacts;

  @override
  UserProfile? contactById(String id) {
    for (final c in _contacts) {
      if (c.id == id) return c;
    }
    return null;
  }

  @override
  bool isBlocked(UserProfile user) => _blockedIds.contains(user.id);

  @override
  Future<void> blockUser(String userId) async {
    _blockedIds.add(userId);
    await _prefs?.setStringList('safety.blocked', _blockedIds.toList());
    await api.setBlocked(userId: userId, blocked: true);
    notifyListeners();
  }

  @override
  Future<void> unblockUser(String userId) async {
    _blockedIds.remove(userId);
    await _prefs?.setStringList('safety.blocked', _blockedIds.toList());
    await api.setBlocked(userId: userId, blocked: false);
    notifyListeners();
  }

  Future<void> _refreshDirectory() async {
    final list = await api.contacts();
    _contacts = list.map(_mapContact).toList();
  }

  // ── Conversations ────────────────────────────────────────────────────────

  @override
  List<Conversation> get conversations {
    final list = _conversations.values.toList();
    list.sort((a, b) {
      final ta = lastMessageOf(a.id)?.createdAt ?? a.createdAt;
      final tb = lastMessageOf(b.id)?.createdAt ?? b.createdAt;
      return tb.compareTo(ta);
    });
    return list;
  }

  @override
  Conversation? conversationOf(String id) => _conversations[id];

  @override
  List<Message> messagesOf(String conversationId) {
    final map = _messages[conversationId];
    if (map == null) return const [];
    final list =
        map.values.toList()..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return list;
  }

  @override
  Message? lastMessageOf(String conversationId) {
    final list = messagesOf(conversationId);
    return list.isEmpty ? null : list.last;
  }

  @override
  int unreadCount(String conversationId) => _unread[conversationId] ?? 0;

  @override
  int get totalUnread => _unread.values.fold(0, (a, b) => a + b);

  @override
  void markRead(String conversationId) {
    _unread[conversationId] = 0;
    unawaited(_withAuth(() => api.markRead(conversationId)));
    notifyListeners();
  }

  @override
  Conversation openWith(UserProfile other) {
    final existing = _conversations.values.where(
      (c) => !c.isGroup && c.members.any((m) => m.id == other.id),
    );
    if (existing.isNotEmpty) return existing.first;
    final conv = _upsertFromRemote(
      remoteCreate: () => api.openConversation(other.id),
      fallback: Conversation(
        id: 'pending-${other.id}',
        members: [other, _me ?? other],
        createdAt: DateTime.now(),
      ),
    );
    return conv;
  }

  @override
  Conversation createConversation(UserProfile other) => openWith(other);

  @override
  Conversation createGroup(String title, List<String> memberIds) {
    return _upsertFromRemote(
      remoteCreate: () => api.createGroup(title, memberIds),
      fallback: Conversation(
        id: 'pending-group-${DateTime.now().millisecondsSinceEpoch}',
        members: [
          for (final id in memberIds)
            if (contactById(id) != null) contactById(id)!,
          if (_me != null) _me!,
        ],
        createdAt: DateTime.now(),
        isGroup: true,
        title: title,
      ),
    );
  }

  /// Calls the API, maps the returned summary into the conversation store,
  /// and returns the conversation. Falls back to [fallback] on error so the
  /// UI keeps a handle (a later sync replaces the placeholder).
  Conversation _upsertFromRemote({
    required Future<Map<String, dynamic>> Function() remoteCreate,
    required Conversation fallback,
  }) {
    Conversation handle = fallback;
    unawaited(() async {
      try {
        final data = await remoteCreate();
        await _absorbSummaries([data]);
        handle = _conversations[fallback.id] ?? fallback;
      } catch (_) {}
      notifyListeners();
    }());
    return handle;
  }

  @override
  void clearConversation(String conversationId) {
    // The API has no per-thread clear (retention is server policy);
    // demo-only affordance → local view reset with an honest semantics.
    _messages.remove(conversationId);
    notifyListeners();
  }

  // ── Messaging ────────────────────────────────────────────────────────────

  @override
  void sendMessage(String conversationId, String text, {String? clientKey}) {
    final meUser = _me;
    if (meUser == null || text.trim().isEmpty) return;
    final clientId = clientKey ?? 'ck-${DateTime.now().microsecondsSinceEpoch}';
    unawaited(() async {
      await _withAuth(
        () => api.sendText(
          conversationId: conversationId,
          text: text.trim(),
          sourceLanguage: meUser.languageCode,
          clientId: clientId,
        ),
      );
      await fetchMessages(conversationId);
      notifyListeners();
    }());
    notifyListeners();
  }

  @override
  Message sendVoiceNote(
    String conversationId,
    Duration duration,
    List<double> waveform, {
    String? filePath,
  }) {
    final meUser = _me;
    if (meUser == null || filePath == null) {
      // Remote mode requires a real recording; never fabricate one.
      throw StateError('Remote voice notes need a recorded file (mobile app).');
    }
    final clientId = 'ck-${DateTime.now().microsecondsSinceEpoch}';
    unawaited(() async {
      await _withAuth(() async {
        final assetId = await api.uploadVoice(
          filePath: filePath,
          durationMs: duration.inMilliseconds,
        );
        await api.sendVoice(
          conversationId: conversationId,
          mediaAssetId: assetId,
          sourceLanguage: meUser.speechLanguageCode ?? meUser.languageCode,
          clientId: clientId,
        );
      });
      await fetchMessages(conversationId);
      notifyListeners();
    }());
    // Optimistic local bubble — replayable from the real file while uploading.
    final localVoice = Message(
      id: 'local-$clientId',
      conversationId: conversationId,
      senderId: meUser.id,
      kind: MessageKind.voice,
      clientKey: clientId,
      createdAt: DateTime.now(),
      voice: VoicePayload(
        jobId: clientId,
        duration: duration,
        waveform: waveform,
        stage: VoiceStage.recorded,
        recordedFilePath: filePath,
      ),
    );
    (_messages.putIfAbsent(conversationId, () => {}))[localVoice.id] =
        localVoice;
    notifyListeners();
    return localVoice;
  }

  @override
  void resendTranslation(String messageId, String targetLanguage) {
    unawaited(_withAuth(() => api.retryTranslation(messageId)));
  }

  @override
  Future<void> retryVoiceSpeech(String messageId) async {
    // The server regenerates speech during its pipeline; there is no
    // dedicated re-TTS endpoint yet — re-running MT is the honest retry.
    await api.retryTranslation(messageId);
  }

  @override
  void deleteMessage(String messageId) {
    unawaited(_withAuth(() => api.deleteMessage(messageId)));
    for (final map in _messages.values) {
      final m = map[messageId];
      if (m != null) {
        map[messageId] = m.copyWith(deleted: true);
      }
    }
    notifyListeners();
  }

  @override
  bool reportMessage(String messageId, String reason) {
    unawaited(_withAuth(() => api.report(messageId, reason)));
    return true;
  }

  @override
  Message createPoll(
    String conversationId,
    String question,
    List<String> options,
  ) {
    // Polls are a demo-tier feature; the live API has no poll contract yet.
    throw UnsupportedError('Polls are demo-only in this build');
  }

  @override
  void votePoll(
    String conversationId,
    String messageId,
    int optionIndex, {
    String? voterId,
  }) {
    throw UnsupportedError('Polls are demo-only in this build');
  }

  @override
  Future<String?> mediaAssetUrl(String assetId) async {
    final uri = await session.resolvePresigned('/api/media/$assetId');
    return uri?.toString();
  }

  // ── Preferences ──────────────────────────────────────────────────────────

  @override
  ThemeMode get themeMode => _themeMode;

  @override
  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    await _prefs?.setInt('ui.themeMode', mode.index);
    notifyListeners();
  }

  @override
  Future<void> setLanguage(String code) async {
    _prefLanguage = code;
    await _prefs?.setString('pref.language', code);
    await _withAuth(() => api.patchMe(preferredLanguage: code));
    if (_me != null) {
      _me = _me!.copyWith(languageCode: code);
    }
    notifyListeners();
  }

  @override
  Future<void> setSpeechLanguage(String code) async {
    await _withAuth(() => api.patchMe(speechLanguage: code));
    if (_me != null) _me = _me!.copyWith(speechLanguageCode: code);
    notifyListeners();
  }

  @override
  Future<void> setVoice(String voiceId) async {
    // The live contract stores voiceId but the TTS engine picks its own
    // voice per language; kept for UI parity.
    await _prefs?.setString('pref.voiceId', voiceId);
    notifyListeners();
  }

  @override
  Future<void> updateProfile({
    String? name,
    String? username,
    String? about,
  }) async {
    if (name != null && name.trim().length >= 2) {
      await _withAuth(() => api.patchMe(displayName: name.trim()));
      if (_me != null) _me = _me!.copyWith(name: name.trim());
    }
    notifyListeners();
  }

  @override
  Future<void> setPrivacyFlag({
    bool? readReceipts,
    bool? lastSeenVisible,
    bool? typingVisible,
    bool? previewVisible,
  }) async {
    if (_me == null) return;
    _me = _me!.copyWith(
      readReceipts: readReceipts,
      lastSeenVisible: lastSeenVisible,
      typingVisible: typingVisible,
      previewVisible: previewVisible,
    );
    await _persistMeShallow();
    notifyListeners();
  }

  Future<void> _persistMeShallow() async {
    final p = _prefs;
    final m = _me;
    if (p == null || m == null) return;
    await p.setString('remote.me.cache', m.id); // presence marker only
  }

  bool get autoTranslate => _autoTranslate;
  @override
  Future<void> setAutoTranslate(bool value) async {
    _autoTranslate = value;
    await _prefs?.setBool('pref.autoTranslate', value);
    notifyListeners();
  }

  bool get autoPlayTranslated => _autoPlayTranslated;
  @override
  Future<void> setAutoPlayTranslated(bool value) async {
    _autoPlayTranslated = value;
    await _prefs?.setBool('pref.autoPlayTranslated', value);
    notifyListeners();
  }

  bool get preferOriginalAudio => _preferOriginalAudio;
  @override
  Future<void> setPreferOriginalAudio(bool value) async {
    _preferOriginalAudio = value;
    await _prefs?.setBool('pref.preferOriginalAudio', value);
    notifyListeners();
  }

  double get playbackRate => _playbackRate;
  @override
  Future<void> setPlaybackRate(double value) async {
    _playbackRate = value.clamp(0.5, 2.0);
    await _prefs?.setDouble('pref.playbackRate', _playbackRate);
    notifyListeners();
  }

  // ── Sync internals ───────────────────────────────────────────────────────

  Future<void> _refreshSummaries() async {
    final data = await api.sync();
    await _absorbSummaries(
      ((data['conversations'] ?? const []) as List)
          .whereType<Map<String, dynamic>>(),
    );
    // The 'now' payload stamp becomes the next delta cursor (WS upgrade will
    // replace this cursor bookkeeping entirely).
    // final now = data['now'];
  }

  Future<void> _absorbSummaries(
    Iterable<Map<String, dynamic>> summaries,
  ) async {
    final myId = _me?.id;
    for (final s in summaries) {
      final id = (s['id'] ?? '') as String;
      if (id.isEmpty || myId == null) continue;
      final membersRaw =
          ((s['members'] ?? const []) as List)
              .whereType<Map<String, dynamic>>();
      final members = membersRaw.map(_contactFromMember).toList();
      // Order others first, me last (model contract).
      final others = members.where((m) => m.id != myId).toList();
      final meMember = members.firstWhere(
        (m) => m.id == myId,
        orElse: () => _me!,
      );
      final last = (s['lastMessage'] ?? null) as Map<String, dynamic>?;
      final unread = (s['unreadCount'] ?? 0) as int;

      _unread[id] = unread;
      _conversations[id] = Conversation(
        id: id,
        members: [...others, meMember],
        createdAt:
            DateTime.tryParse((s['createdAt'] ?? '') as String) ??
            DateTime.now(),
        isGroup: (s['type'] ?? 'direct') == 'group',
        title: s['title'] as String?,
      );

      final preview =
          last == null
              ? null
              : Message(
                id: (last['id'] ?? 'last-$id') as String,
                conversationId: id,
                senderId: (last['senderId'] ?? '') as String,
                kind: MessageKind.text,
                text: (last['preview'] ?? '') as String,
                sourceLanguage: '',
                createdAt:
                    DateTime.tryParse((last['createdAt'] ?? '') as String) ??
                    DateTime.now(),
                deleted: (last['deleted'] ?? false) as bool,
              );
      if (preview != null && last != null) {
        final map = _messages.putIfAbsent(id, () => {});
        // Only a preview-level placeholder: real messages replace it.
        map.putIfAbsent(preview.stableKey, () => preview);
      }
    }
  }

  UserProfile _contactFromMember(Map<String, dynamic> m) {
    return UserProfile(
      id: (m['id'] ?? '') as String,
      name: (m['displayName'] ?? 'Unknown') as String,
      username: (m['username'] ?? '') as String,
      languageCode: (m['preferredLanguage'] ?? 'en') as String,
      presence: Presence(
        online: (m['online'] ?? false) as bool,
        lastSeen:
            m['lastSeenAt'] == null
                ? null
                : DateTime.tryParse(m['lastSeenAt'] as String),
      ),
      avatarUrl: m['avatarUrl'] as String?,
    ).withAbsoluteAvatar(session.baseUrl);
  }

  Future<void> _fetchTypers(String conversationId) async {
    // Typing heartbeats ride the same sync payload via the scoped call.
    final data = await api.sync();
    final typers =
        ((data['typers'] ?? const []) as List).whereType<String>().toSet();
    if (typers.isEmpty) {
      _typers.remove(conversationId);
      _conversations[conversationId]?.copyWith(typingUserIds: const {});
    } else {
      _typers[conversationId] = typers;
    }
    final conv = _conversations[conversationId];
    if (conv != null) {
      final typing = _typers[conversationId] ?? const <String>{};
      _conversations[conversationId] = conv.copyWith(typingUserIds: typing);
    }
  }

  Future<void> fetchMessages(String conversationId) async {
    final myLang = _me?.languageCode ?? 'en';
    final myId = _me?.id;
    if (myId == null) return;
    final list = await api.messages(conversationId);
    final map = _messages.putIfAbsent(conversationId, () => {});
    for (final v in list) {
      final mapped = _mapMessage(v, myLang, myId);
      map[mapped.id] = mapped;
    }
    // Drop stale preview placeholders once real messages exist.
    map.removeWhere(
      (key, m) =>
          key.startsWith('last-') &&
          map.values.any(
            (x) => x.stableKey != key && x.createdAt.isAfter(m.createdAt),
          ),
    );
    if (_activeConversation == conversationId &&
        conversationId.startsWith('conv'))
      await _withAuth(() => api.markRead(conversationId));
    _unread[conversationId] = 0;
    notifyListeners();
  }

  Future<void> _withAuth(Future<void> Function() fn) async {
    try {
      await fn();
    } on ApiError catch (e) {
      if (e.unauthorized) {
        stopTimers();
        _me = null;
        notifyListeners();
        return;
      }
      rethrow;
    }
  }
}

extension on UserProfile {
  /// Session cookies do not apply to presigned avatar GETs; the avatar route
  /// authenticates via the session cookie — so relative URLs must carry the
  /// same origin the cookies were issued for.
  UserProfile withAbsoluteAvatar(String baseUrl) {
    final u = avatarUrl;
    if (u == null || u.startsWith('http')) return this;
    final base =
        baseUrl.endsWith('/')
            ? baseUrl.substring(0, baseUrl.length - 1)
            : baseUrl;
    return copyWith(avatarUrl: '$base$u');
  }
}
