import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show ThemeMode;
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/utils.dart';
import '../demo/demo_translator.dart';
import '../backend_base.dart';
import '../models/conversation.dart';
import '../models/language.dart';
import '../models/message.dart';
import '../models/user.dart';

/// In-memory demo backend + orchestration engine.
///
/// Stands in for the NestJS API, BullMQ workers and the pluggable AI
/// provider adapters described in the architecture. Every screen talks to
/// this notify-driven service, so replacing it with real repositories is a
/// drop-in change.
class MockBackend extends UniBackend {
  @override
  Future<String?> mediaAssetUrl(String assetId) async {
    // Demo tones resolve locally in the playback controller; nothing to fetch.
    return null;
  }

  MockBackend();

  final Random _rnd = Random();

  // ── Session ──────────────────────────────────────────────────────────────
  UserProfile? me;
  SharedPreferences? prefs;
  ThemeMode themeMode = ThemeMode.dark;

  // ── Translation & playback preferences ──────────────────────────────────
  /// Incoming messages/voice notes translate automatically. Off = manual
  /// via the View-translation control or Retry.
  bool autoTranslate = true;

  /// Auto-play translated voice audio when it becomes ready. Off by
  /// default — unexpected sound is a privacy and etiquette hazard.
  bool autoPlayTranslated = false;

  /// When both original and translated audio exist, prefer playing the
  /// original first.
  bool preferOriginalAudio = false;

  /// Playback speed for voice notes (0.75–2.0).
  double playbackRate = 1.0;

  Future<void> setAutoTranslate(bool value) async {
    autoTranslate = value;
    await prefs?.setBool('pref.autoTranslate', value);
    notifyListeners();
  }

  Future<void> setAutoPlayTranslated(bool value) async {
    autoPlayTranslated = value;
    await prefs?.setBool('pref.autoPlayTranslated', value);
    notifyListeners();
  }

  Future<void> setPreferOriginalAudio(bool value) async {
    preferOriginalAudio = value;
    await prefs?.setBool('pref.preferOriginalAudio', value);
    notifyListeners();
  }

  Future<void> setPlaybackRate(double value) async {
    playbackRate = value.clamp(0.5, 2.0);
    await prefs?.setDouble('pref.playbackRate', playbackRate);
    notifyListeners();
  }

  bool get isSignedIn => me != null;
  bool get onboarded => me != null && prefs?.getString('pref.language') != null;

  // ── Stores ───────────────────────────────────────────────────────────────
  final Map<String, Conversation> _conversations = {};
  final Map<String, Map<String, Message>> _messages = {};
  final Map<String, DateTime> _lastReadAt = {};
  final Set<String> _blockedIds = {};
  final Map<String, int> _replyStreaks = {};
  final Set<String> _voiceRepliedConversations = {};
  bool _seeded = false;
  int _voiceCounter = 0;

  // ── Queries ──────────────────────────────────────────────────────────────
  List<Conversation> get conversations {
    final list = _conversations.values.toList();
    list.sort((a, b) {
      final ta = lastMessageOf(a.id)?.createdAt ?? a.createdAt;
      final tb = lastMessageOf(b.id)?.createdAt ?? b.createdAt;
      return tb.compareTo(ta);
    });
    return list;
  }

  Conversation? conversationOf(String id) => _conversations[id];

  List<Message> messagesOf(String conversationId) =>
      (_messages[conversationId]?.values.toList() ?? [])
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

  Message? lastMessageOf(String conversationId) {
    final list = messagesOf(conversationId);
    return list.isEmpty ? null : list.last;
  }

  int unreadCount(String conversationId) =>
      messagesOf(conversationId)
          .where((m) => m.senderId != me?.id && !_isRead(conversationId, m))
          .length;

  int get totalUnread =>
      _conversations.keys.fold(0, (n, id) => n + unreadCount(id));

  bool _isRead(String conversationId, Message m) {
    final readAt = _lastReadAt[conversationId];
    return readAt != null && !m.createdAt.isAfter(readAt);
  }

  Message? messageById(String id) {
    for (final map in _messages.values) {
      final m = map[id];
      if (m != null) return m;
    }
    return null;
  }

  bool isBlocked(UserProfile user) => _blockedIds.contains(user.id);

  // ── Boot / persistence ───────────────────────────────────────────────────
  Future<void> load() async {
    prefs = await SharedPreferences.getInstance();
    final raw = prefs!.getString('me.profile');
    if (raw != null && raw.isNotEmpty) {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      me = UserProfile(
        id: (map['id'] as String?) ?? newId('usr'),
        name: (map['name'] as String?) ?? 'You',
        username: (map['username'] as String?) ?? 'you',
        languageCode: (map['languageCode'] as String?) ?? 'en',
        speechLanguageCode: map['speechLanguageCode'] as String?,
        voiceId: map['voiceId'] as String?,
        about: (map['about'] as String?) ?? 'Living between languages.',
        colorSeed: 3,
      );
    }
    themeMode = ThemeMode.values[prefs!.getInt('ui.themeMode') ?? 0];
    autoTranslate = prefs!.getBool('pref.autoTranslate') ?? true;
    autoPlayTranslated = prefs!.getBool('pref.autoPlayTranslated') ?? false;
    preferOriginalAudio = prefs!.getBool('pref.preferOriginalAudio') ?? false;
    playbackRate = prefs!.getDouble('pref.playbackRate') ?? 1.0;
    _blockedIds.addAll(prefs!.getStringList('safety.blocked') ?? []);
    ready = true;
    notifyListeners();
  }

  Future<void> _persistProfile() async {
    final p = prefs;
    final m = me;
    if (p == null || m == null) return;
    await p.setString(
      'me.profile',
      jsonEncode({
        'id': m.id,
        'name': m.name,
        'username': m.username,
        'languageCode': m.languageCode,
        'speechLanguageCode': m.speechLanguageCode,
        'voiceId': m.voiceId,
        'about': m.about,
      }),
    );
  }

  LanguageInfo get myLanguage => LanguageRegistry.of(me?.languageCode);

  Future<void> setThemeMode(ThemeMode mode) async {
    themeMode = mode;
    await prefs?.setInt('ui.themeMode', mode.index);
    notifyListeners();
  }

  // ── Auth (mock) ──────────────────────────────────────────────────────────
  Future<void> register({
    required String name,
    required String username,
    String? password,
    String? email,
  }) async {
    me = UserProfile(
      id: newId('usr'),
      name: name,
      username: username,
      languageCode: 'en',
      about: 'Living between languages.',
      colorSeed: name.length % 8,
    );
    await _persistProfile();
    notifyListeners();
  }

  Future<void> signIn(String email, {String? password}) async {
    if (me == null) {
      final guessed = email
          .split('@')
          .first
          .replaceAll(RegExp(r'[^a-z0-9]'), '');
      me = UserProfile(
        id: newId('usr'),
        name: _titleCase(guessed.isEmpty ? 'You' : guessed),
        username: guessed.isEmpty ? 'you' : guessed,
        languageCode: 'en',
        about: 'Living between languages.',
        colorSeed: 3,
      );
      await _persistProfile();
    }
    notifyListeners();
  }

  Future<void> signOut() async {
    me = null;
    _conversations.clear();
    _messages.clear();
    _lastReadAt.clear();
    _voiceRepliedConversations.clear();
    _seeded = false;
    await prefs?.remove('me.profile');
    await prefs?.remove('pref.language');
    notifyListeners();
  }

  // ── Preferences ──────────────────────────────────────────────────────────
  Future<void> setLanguage(String code) async {
    if (me == null) return;
    me = me!.copyWith(languageCode: code, speechLanguageCode: code);
    await prefs?.setString('pref.language', code);
    await _persistProfile();
    notifyListeners();
  }

  Future<void> setSpeechLanguage(String code) async {
    me = me?.copyWith(speechLanguageCode: code);
    await _persistProfile();
    notifyListeners();
  }

  Future<void> setVoice(String voiceId) async {
    me = me?.copyWith(voiceId: voiceId);
    await _persistProfile();
    notifyListeners();
  }

  @override
  Future<void> updateProfile({
    String? name,
    String? username,
    String? about,
  }) async {
    me = me?.copyWith(name: name, username: username, about: about);
    await _persistProfile();
    notifyListeners();
  }

  Future<void> setPrivacyFlag({
    bool? readReceipts,
    bool? lastSeenVisible,
    bool? typingVisible,
    bool? previewVisible,
  }) async {
    me = me?.copyWith(
      readReceipts: readReceipts,
      lastSeenVisible: lastSeenVisible,
      typingVisible: typingVisible,
      previewVisible: previewVisible,
    );
    await _persistProfile();
    notifyListeners();
  }

  // ── Contacts ─────────────────────────────────────────────────────────────
  static final List<UserProfile> _demoContacts = [
    const UserProfile(
      id: 'usr_diego',
      name: 'Diego Ramírez',
      username: 'diego.r',
      languageCode: 'es',
      about: 'CDMX → world 🌎',
      presence: Presence(online: true),
    ),
    const UserProfile(
      id: 'usr_amara',
      name: 'Amara Okafor',
      username: 'amara.ọ',
      languageCode: 'yo',
      about: 'Lagos • storytelling in Yorùbá',
      presence: Presence(online: true),
    ),
    const UserProfile(
      id: 'usr_elodie',
      name: 'Élodie Marchand',
      username: 'elodie.m',
      languageCode: 'fr',
      about: 'Paris. Caféophilie.',
      presence: Presence(online: false),
    ),
    const UserProfile(
      id: 'usr_kwame',
      name: 'Kwame Mensah',
      username: 'kwame.h',
      languageCode: 'ha',
      about: 'Kano ↔ online',
      presence: Presence(online: true),
    ),
    const UserProfile(
      id: 'usr_fatima',
      name: 'Fatima Al-Sayed',
      username: 'fatima.a',
      languageCode: 'ar',
      about: 'الرياض • تصميم',
      presence: Presence(online: false),
    ),
    const UserProfile(
      id: 'usr_lin',
      name: 'Lin Wei',
      username: 'lin.w',
      languageCode: 'zh',
      about: 'Shanghai',
      presence: Presence(online: false),
    ),
    const UserProfile(
      id: 'usr_sofia',
      name: 'Sofia Duarte',
      username: 'sofia.p',
      languageCode: 'pt',
      about: 'Lisboa',
      presence: Presence(online: false),
    ),
  ];

  UserProfile? contactById(String id) {
    for (final c in _demoContacts) {
      if (c.id == id) return c;
    }
    return null;
  }

  /// Instance view of the demo contact book (screens use this).
  List<UserProfile> get contacts => MockBackend._demoContacts;

  // ── Conversations ────────────────────────────────────────────────────────
  Conversation openWith(UserProfile other) {
    for (final c in _conversations.values) {
      if (c.members.isNotEmpty && c.members.first.id == other.id) return c;
    }
    return createConversation(other);
  }

  Conversation createConversation(UserProfile other) {
    final conv = Conversation(
      id: newId('conv'),
      members: [other, me!],
      createdAt: DateTime.now(),
    );
    _conversations[conv.id] = conv;
    notifyListeners();
    return conv;
  }

  /// Seeds the demo world once per session (safe after app restarts).
  void ensureSeeded() {
    if (_seeded) return;
    seedConversations();
  }

  /// Seeds a rich demo world relative to the signed-in user's language.
  void seedConversations() {
    if (me == null) return;
    final now = DateTime.now();
    _seeded = true;

    UserProfile other(String id) => _demoContacts.firstWhere(
      (c) => c.id == id,
      orElse: () => contacts.first,
    );

    void seed(
      String contactId,
      List<({String speakerId, String text, int minutesAgo})> script, {
      bool unreadTail = false,
    }) {
      final o = other(contactId);
      final conv = Conversation(
        id: newId('conv'),
        members: [o, me!],
        createdAt: now.subtract(const Duration(days: 6)),
      );
      _conversations[conv.id] = conv;
      final firstAt = script.first.minutesAgo;
      for (final line in script) {
        final msg = Message(
          id: newId('msg'),
          conversationId: conv.id,
          senderId: line.speakerId,
          kind: MessageKind.text,
          text: line.text,
          sourceLanguage:
              line.speakerId == me!.id ? me!.languageCode : o.languageCode,
          createdAt: now.subtract(Duration(minutes: line.minutesAgo)),
          delivery: MessageDelivery.read,
        );
        _messages.putIfAbsent(conv.id, () => {})[msg.id] = msg;
      }
      final readFrom =
          unreadTail
              ? now.subtract(Duration(minutes: firstAt - 1))
              : now.add(const Duration(minutes: 1));
      _lastReadAt[conv.id] = readFrom;
    }

    String mine = me!.id;

    seed('usr_diego', [
      (speakerId: mine, text: _ph('hello_how_are_you', 'en'), minutesAgo: 1410),
      (speakerId: 'usr_diego', text: _ph('welcome', 'es'), minutesAgo: 1404),
      (speakerId: mine, text: _ph('im_fine_thanks', 'en'), minutesAgo: 1400),
      (speakerId: mine, text: _ph('what_are_you_doing', 'en'), minutesAgo: 38),
      (
        speakerId: 'usr_diego',
        text: _ph('see_you_tomorrow', 'es'),
        minutesAgo: 34,
      ),
    ], unreadTail: true);

    seed('usr_amara', [
      (speakerId: mine, text: _ph('good_morning', 'en'), minutesAgo: 2200),
      (
        speakerId: 'usr_amara',
        text: _ph('hello_how_are_you', 'yo'),
        minutesAgo: 2196,
      ),
      (speakerId: mine, text: _ph('call_me', 'en'), minutesAgo: 1900),
      (
        speakerId: 'usr_amara',
        text: _ph('landed_airport', 'yo'),
        minutesAgo: 1800,
      ),
    ]);

    seed('usr_kwame', [
      (
        speakerId: 'usr_kwame',
        text: _ph('good_morning', 'ha'),
        minutesAgo: 3000,
      ),
      (speakerId: mine, text: _ph('how_much_is_this', 'en'), minutesAgo: 2995),
      (speakerId: 'usr_kwame', text: _ph('thank_you', 'ha'), minutesAgo: 2990),
    ]);

    seed('usr_fatima', [
      (speakerId: mine, text: _ph('welcome', 'en'), minutesAgo: 4400),
      (
        speakerId: 'usr_fatima',
        text: _ph('wait_for_me', 'ar'),
        minutesAgo: 4390,
      ),
    ]);

    seed('usr_lin', [
      (speakerId: 'usr_lin', text: '你好！很高兴认识你。', minutesAgo: 5900),
    ]);

    seed('usr_sofia', [
      (speakerId: mine, text: _ph('hello_how_are_you', 'en'), minutesAgo: 7000),
      (speakerId: 'usr_sofia', text: _ph('thank_you', 'pt'), minutesAgo: 6990),
    ]);

    _seedVoiceMessage(
      conversationId: _conversations.keys.firstWhere(
        (id) => _conversations[id]!.members.first.id == 'usr_amara',
        orElse: () => _conversations.keys.first,
      ),
    );

    _seedGroupConversation();

    notifyListeners();
  }

  /// Group chat seed — "Team Align": Amara · Diego · Kwame in one thread,
  /// each speaking their own language while I see my own.
  void _seedGroupConversation() {
    if (me == null) return;
    final now = DateTime.now();
    UserProfile other(String id) => contactById(id) ?? contacts.first;
    final mine = me!.id;
    final members =
        ['usr_amara', 'usr_diego', 'usr_kwame'].map(other).toList()..add(me!);
    final conv = Conversation(
      id: 'conv_team_align',
      members: members,
      createdAt: now.subtract(const Duration(days: 12)),
      isGroup: true,
      title: 'Team Align',
    );
    _conversations[conv.id] = conv;

    final script = <({String speakerId, String text, int minutesAgo})>[
      (
        speakerId: 'usr_amara',
        text: _ph('good_morning', 'yo'),
        minutesAgo: 720,
      ),
      (
        speakerId: 'usr_diego',
        text: _ph('what_are_you_doing', 'es'),
        minutesAgo: 700,
      ),
      (speakerId: mine, text: _ph('see_you_tomorrow', 'en'), minutesAgo: 660),
      (speakerId: 'usr_kwame', text: _ph('thank_you', 'ha'), minutesAgo: 600),
      (
        speakerId: 'usr_amara',
        text: _ph('hello_how_are_you', 'yo'),
        minutesAgo: 45,
      ),
    ];
    for (final line in script) {
      final speaker = line.speakerId == me!.id ? me! : other(line.speakerId);
      final msg = Message(
        id: newId('msg'),
        conversationId: conv.id,
        senderId: line.speakerId,
        kind: MessageKind.text,
        text: line.text,
        sourceLanguage: speaker.languageCode,
        createdAt: now.subtract(Duration(minutes: line.minutesAgo)),
        delivery: MessageDelivery.read,
      );
      _messages.putIfAbsent(conv.id, () => {})[msg.id] = msg;
    }
    _lastReadAt[conv.id] = now.subtract(
      Duration(minutes: script.first.minutesAgo - 1),
    );
  }

  /// Creates a group from the contacts screen selection.
  Conversation createGroup(String title, List<String> memberIds) {
    final members = <UserProfile>[
      for (final id in memberIds)
        if (id != me!.id && contactById(id) != null) contactById(id)!,
      me!,
    ];
    final conv = Conversation(
      id: newId('conv'),
      members: members,
      createdAt: DateTime.now(),
      isGroup: true,
      title: title.trim().isEmpty ? 'New group' : title.trim(),
    );
    _conversations[conv.id] = conv;
    notifyListeners();
    return conv;
  }

  /// Swipe-to-delete on Home: clears every message but keeps the thread.
  void clearConversation(String conversationId) {
    _messages.remove(conversationId);
    _replyStreaks.remove(conversationId);
    notifyListeners();
  }

  // ── Polls ────────────────────────────────────────────────────────────────
  Message createPoll(
    String conversationId,
    String question,
    List<String> options,
  ) {
    final conv = _conversations[conversationId];
    final meUser = me;
    if (conv == null || meUser == null) {
      throw StateError('conversation or session missing');
    }
    final msg = Message(
      id: newId('msg'),
      conversationId: conversationId,
      senderId: meUser.id,
      kind: MessageKind.poll,
      clientKey: newId('ck'),
      createdAt: DateTime.now(),
      poll: PollPayload(
        question: question.trim(),
        options: options,
        votes: const {},
      ),
    );
    _put(msg);
    _replyStreaks[conversationId] = 0;
    notifyListeners();

    // Group members cast opinions a moment later so tallies move.
    for (final member in conv.members) {
      if (member.id == meUser.id) continue;
      unawaited(
        Future.delayed(Duration(milliseconds: 1200 + _rnd.nextInt(2600)), () {
          if (_conversations[conversationId] == null) return;
          votePoll(
            conversationId,
            msg.id,
            _rnd.nextInt(options.length.clamp(2, 4)),
            voterId: member.id,
          );
        }),
      );
    }
    return msg;
  }

  /// Cast or switch my (or, for simulation, anyone's) vote on a poll.
  void votePoll(
    String conversationId,
    String messageId,
    int optionIndex, {
    String? voterId,
  }) {
    final base = messageById(messageId);
    final poll = base?.poll;
    if (base == null || poll == null) return;
    if (optionIndex < 0 || optionIndex >= poll.options.length) return;
    final voter = voterId ?? me!.id;

    final votes = <int, List<String>>{
      for (final e in poll.votes.entries) e.key: List.of(e.value),
      for (var i = 0; i < poll.options.length; i++)
        i: List<String>.of(poll.votes[i] ?? const <String>[]),
    };
    // A single voter fills exactly one option at a time.
    for (final e in votes.entries) {
      e.value.remove(voter);
    }
    votes.putIfAbsent(optionIndex, () => []).add(voter);

    _mutate(messageId, (m) {
      return m.copyWith(
        poll: poll.copyWith(
          votes: votes,
          myVote: voter == me!.id ? optionIndex : m.poll?.myVote,
        ),
      );
    });
    notifyListeners();
  }

  String _ph(String key, String lang) =>
      DemoPhrases.book[key]?[lang] ?? DemoPhrases.book[key]?['en'] ?? key;

  /// A finished voice note from Amara (completed pipeline with TTS) plus a
  /// partial one from Élodie (TTS failed → partial state + retry affordance).
  void _seedVoiceMessage({required String conversationId}) {
    final conv = _conversations[conversationId];
    if (conv == null) return;
    final o = conv.members.first;
    final speakerLang = o.languageCode;
    final targetLang = me?.speechLanguageCode ?? me?.languageCode ?? 'en';
    final transcript =
        DemoPhrases.voiceTranscripts[0][speakerLang] ??
        DemoPhrases.voiceTranscripts[0]['en']!;
    final translated =
        DemoPhrases.voiceTranscripts[0][targetLang] ?? transcript;
    final bool ttsOk = LanguageRegistry.of(targetLang).tts;

    final msg = Message(
      id: newId('msg'),
      conversationId: conversationId,
      senderId: o.id,
      kind: MessageKind.voice,
      sourceLanguage: speakerLang,
      createdAt: DateTime.now().subtract(const Duration(hours: 26)),
      voice: VoicePayload(
        jobId: newId('job'),
        duration: const Duration(seconds: 7),
        waveform: Message.seededWaveform('amara-voice-demo'),
        stage: ttsOk ? VoiceStage.completed : VoiceStage.partial,
        transcript: transcript,
        detectedLanguage: speakerLang,
        translatedTranscripts: {targetLang: translated},
        audioVariants: ttsOk ? {targetLang: true} : {},
        error:
            ttsOk
                ? null
                : 'Speech synthesis unavailable for this language (demo).',
        storageKey: 'private/audio/demo_amara.m4a',
      ),
    );
    _messages.putIfAbsent(conversationId, () => {})[msg.id] = msg;
  }

  // ── Read state / startup translation ─────────────────────────────────────
  void markRead(String conversationId) {
    _lastReadAt[conversationId] = DateTime.now();
    _translateUnreadIncoming(conversationId);
    notifyListeners();
  }

  /// When a chat opens, unseen incoming messages start translating live —
  /// the app's signature moment.
  void _translateUnreadIncoming(String conversationId) {
    final conv = _conversations[conversationId];
    final myLang = me?.languageCode;
    if (conv == null || myLang == null) return;
    // "Automatic translation" can be disabled per user; manual retry and the
    // View-translation control still work either way.
    if (!autoTranslate) return;
    for (final m in messagesOf(conversationId)) {
      if (m.senderId == me!.id) continue;
      if (m.kind != MessageKind.text) continue;
      final has = m.translations[myLang];
      if (has != null && has.status == TranslationStatus.completed) continue;
      _scheduleTranslation(
        m.id,
        m.sourceLanguage ?? conv.members.first.languageCode,
        myLang,
      );
    }

    // One-time simulated incoming voice note per online partner.
    final other = conv.members.first;
    if (other.presence.online &&
        !_voiceRepliedConversations.contains(conversationId)) {
      _voiceRepliedConversations.add(conversationId);
      Future.delayed(const Duration(milliseconds: 2600), () {
        if (_conversations[conversationId] == null || me == null) return;
        _sendIncomingVoiceNote(conversationId);
      });
    }
  }

  // ── Messaging pipeline ───────────────────────────────────────────────────
  void sendMessage(String conversationId, String text, {String? clientKey}) {
    final conv = _conversations[conversationId];
    final meUser = me;
    if (conv == null || meUser == null || text.trim().isEmpty) return;
    if (!conv.isGroup && isBlocked(conv.members.first)) return;

    final msg = Message(
      id: newId('msg'),
      conversationId: conversationId,
      senderId: meUser.id,
      kind: MessageKind.text,
      text: text.trim(),
      sourceLanguage: meUser.languageCode,
      clientKey: clientKey ?? newId('ck'),
      createdAt: DateTime.now(),
    );

    _put(msg);
    _replyStreaks[conversationId] = 0;
    notifyListeners();

    // Delivery receipts: sent → delivered → read.
    Future.delayed(const Duration(milliseconds: 500), () {
      _mutate(msg.id, (m) => m.copyWith(delivery: MessageDelivery.sent));
      notifyListeners();
    });
    Future.delayed(const Duration(milliseconds: 1400), () {
      _mutate(msg.id, (m) => m.copyWith(delivery: MessageDelivery.delivered));
      notifyListeners();
    });
    Future.delayed(const Duration(milliseconds: 3600), () {
      _mutate(msg.id, (m) => m.copyWith(delivery: MessageDelivery.read));
      notifyListeners();
    });

    // Recipient-specific routing: one canonical message, one translation
    // record per distinct recipient language. In 1:1s that's the peer; in
    // groups every other member gets their own language version.
    final targets = <String>{
      for (final member in conv.members)
        if (member.id != meUser.id) member.languageCode,
    };
    for (final target in targets) {
      _scheduleTranslation(msg.id, meUser.languageCode, target);
    }

    // Demo side-effect: a reply from one recipient (random online member).
    final peer = conv.isGroup ? _randomOnlinePeer(conv) : conv.members.first;
    _maybeReply(conversationId, peer);
  }

  UserProfile _randomOnlinePeer(Conversation conv) {
    final candidates =
        conv.members.where((m) => m.id != me!.id && m.presence.online).toList();
    if (candidates.isEmpty) {
      return conv.members.firstWhere(
        (m) => m.id != me!.id,
        orElse: () => conv.members.first,
      );
    }
    return candidates[_rnd.nextInt(candidates.length)];
  }

  /// Manual retry entry point (bubble → "Retry").
  void resendTranslation(String messageId, String targetLanguage) {
    final m = messageById(messageId);
    if (m == null) return;
    _scheduleTranslation(
      m.id,
      m.sourceLanguage ?? DemoTranslator.detect(m.text ?? '') ?? 'en',
      targetLanguage,
    );
  }

  Future<void> _scheduleTranslation(
    String messageId,
    String source,
    String target,
  ) async {
    if (source == target) return;
    _applyTranslation(
      messageId,
      Translation(
        targetLanguage: target,
        status: TranslationStatus.translating,
      ),
    );
    notifyListeners();

    await Future.delayed(Duration(milliseconds: 1400 + _rnd.nextInt(1600)));
    final m = messageById(messageId);
    if (m == null) return;

    if (!LanguageRegistry.of(target).mt) {
      _applyTranslation(
        messageId,
        Translation(
          targetLanguage: target,
          status: TranslationStatus.unavailable,
          errorMessage: 'No provider enabled for this language pair (demo).',
        ),
      );
      notifyListeners();
      return;
    }

    final translated = DemoTranslator.translate(m.text ?? '', source, target);
    if (translated != null) {
      _applyTranslation(
        messageId,
        Translation(
          targetLanguage: target,
          status: TranslationStatus.completed,
          text: translated,
        ),
      );
    } else {
      _applyTranslation(
        messageId,
        Translation(
          targetLanguage: target,
          status: TranslationStatus.unavailable,
          errorMessage:
              'Demo phrasebook miss — a real provider would translate this.',
        ),
      );
    }
    notifyListeners();
  }

  // ── Simulated partner replies ────────────────────────────────────────────
  Future<void> _maybeReply(String conversationId, UserProfile other) async {
    if (!other.presence.online || isBlocked(other)) return;
    final streak = _replyStreaks[conversationId] ?? 0;
    if (streak >= 3) return;
    _replyStreaks[conversationId] = streak + 1;

    _setTyping(conversationId, other.id, true);
    await Future.delayed(Duration(milliseconds: 1600 + _rnd.nextInt(1500)));
    final conv = _conversations[conversationId];
    if (conv == null || me == null) return;
    _setTyping(conversationId, other.id, false);

    final pool =
        DemoTranslator.servedLanguages.contains(other.languageCode)
            ? DemoPhrases.book.values
                .map((m) => m[other.languageCode])
                .whereType<String>()
                .toList()
            : <String>['(demo: no reply expected here)'];
    final text = pool[_rnd.nextInt(pool.length)];

    final msg = Message(
      id: newId('msg'),
      conversationId: conversationId,
      senderId: other.id,
      kind: MessageKind.text,
      text: text,
      sourceLanguage: other.languageCode,
      createdAt: DateTime.now(),
    );
    _put(msg);
    _replyStreaks[conversationId] = 0;
    _scheduleTranslation(msg.id, other.languageCode, me!.languageCode);
    notifyListeners();
  }

  void _setTyping(String conversationId, String userId, bool typing) {
    final conv = _conversations[conversationId];
    if (conv == null) return;
    final set = Set<String>.of(conv.typingUserIds);
    if (typing) {
      set.add(userId);
    } else {
      set.remove(userId);
    }
    _conversations[conversationId] = conv.copyWith(typingUserIds: set);
    notifyListeners();
  }

  // ── Voice pipeline ───────────────────────────────────────────────────────
  Message sendVoiceNote(
    String conversationId,
    Duration duration,
    List<double> waveform, {
    String? filePath,
  }) {
    final conv = _conversations[conversationId];
    final meUser = me;
    if (conv == null || meUser == null) {
      throw StateError('conversation or session missing');
    }
    final jobId = newId('job');
    final msg = Message(
      id: newId('msg'),
      conversationId: conversationId,
      senderId: meUser.id,
      kind: MessageKind.voice,
      sourceLanguage: meUser.speechLanguageCode,
      clientKey: newId('ck'),
      createdAt: DateTime.now(),
      voice: VoicePayload(
        jobId: jobId,
        duration: duration,
        waveform: waveform,
        // Real recorded audio when the mic produced a file; otherwise a
        // broker storage key the demo pipeline pretends was uploaded.
        recordedFilePath: filePath,
        storageKey: 'private/audio/$jobId.m4a',
        stage: VoiceStage.recorded,
      ),
    );
    _put(msg);
    notifyListeners();
    unawaited(_runVoicePipeline(msg.id));
    return msg;
  }

  void _sendIncomingVoiceNote(String conversationId) {
    final conv = _conversations[conversationId];
    if (conv == null || me == null) return;
    final o = conv.members.first;
    final msg = Message(
      id: newId('msg'),
      conversationId: conversationId,
      senderId: o.id,
      kind: MessageKind.voice,
      sourceLanguage: o.speechLanguageCode ?? o.languageCode,
      createdAt: DateTime.now(),
      voice: VoicePayload(
        jobId: newId('job'),
        duration: const Duration(seconds: 8),
        waveform: Message.seededWaveform('incoming-$conversationId'),
        storageKey: 'private/audio/incoming.m4a',
        stage: VoiceStage.recorded,
      ),
    );
    _put(msg);
    _replyStreaks[conversationId] = 0;
    notifyListeners();
    unawaited(_runVoicePipeline(msg.id));
  }

  Future<void> _runVoicePipeline(String messageId) async {
    Future<void> setStage(
      VoiceStage s, {
      String? transcript,
      String? detected,
      Map<String, String>? translated,
      Map<String, bool>? audio,
      String? error,
    }) async {
      _mutate(messageId, (m) {
        final v = m.voice;
        if (v == null) return m;
        return m.copyWith(
          voice: v.copyWith(
            stage: s,
            transcript: transcript,
            detectedLanguage: detected,
            translatedTranscripts: translated,
            audioVariants: audio,
            error: error,
          ),
        );
      });
      notifyListeners();
    }

    final m0 = messageById(messageId);
    if (m0 == null || m0.voice == null) return;
    final conv = _conversations[m0.conversationId];
    final bool outgoing = m0.senderId == me?.id;

    final speakerLang =
        outgoing
            ? (me?.speechLanguageCode ?? me?.languageCode ?? 'en')
            : (conv?.members.first.speechLanguageCode ??
                conv?.members.first.languageCode ??
                'en');
    final targetLang =
        outgoing
            ? (conv?.members.first.speechLanguageCode ??
                conv?.members.first.languageCode ??
                'en')
            : (me?.speechLanguageCode ?? me?.languageCode ?? 'en');

    await setStage(VoiceStage.uploading);
    await Future.delayed(const Duration(milliseconds: 900));
    await setStage(VoiceStage.queued);
    await Future.delayed(const Duration(milliseconds: 650));
    await setStage(VoiceStage.transcribing);
    await Future.delayed(const Duration(milliseconds: 1800));

    final idx = _voiceCounter % DemoPhrases.voiceTranscripts.length;
    _voiceCounter += 1;
    final all = DemoPhrases.voiceTranscripts[idx];
    final transcript = all[speakerLang] ?? all['en']!;
    await setStage(
      VoiceStage.transcribing,
      transcript: transcript,
      detected: speakerLang,
    );
    await Future.delayed(const Duration(milliseconds: 600));

    await setStage(VoiceStage.translating);
    await Future.delayed(const Duration(milliseconds: 1600));
    final translated = all[targetLang] ?? transcript;
    await setStage(
      VoiceStage.translating,
      translated: {targetLang: translated},
    );

    if (!LanguageRegistry.of(targetLang).tts) {
      await setStage(
        VoiceStage.partial,
        error:
            'Speech synthesis unavailable in ${LanguageRegistry.of(targetLang).name} (demo).',
      );
      notifyListeners();
      return;
    }

    await setStage(VoiceStage.synthesizing);
    await Future.delayed(const Duration(milliseconds: 1700));
    await setStage(VoiceStage.completed, audio: {targetLang: true});
    notifyListeners();

    if (outgoing && conv != null) {
      unawaited(_maybeReply(conv.id, conv.members.first));
    }
  }

  Future<void> retryVoiceSpeech(String messageId) async {
    final m = messageById(messageId);
    if (m == null || m.voice == null) return;
    final targetLang = me?.speechLanguageCode ?? me?.languageCode ?? 'en';
    if (!LanguageRegistry.of(targetLang).tts) return;
    _mutate(messageId, (m) {
      final v = m.voice!;
      return m.copyWith(
        voice: v.copyWith(stage: VoiceStage.synthesizing, error: null),
      );
    });
    notifyListeners();
    await Future.delayed(const Duration(milliseconds: 1600));
    _mutate(messageId, (m) {
      final v = m.voice!;
      return m.copyWith(
        voice: v.copyWith(
          stage: VoiceStage.completed,
          audioVariants: {targetLang: true},
        ),
      );
    });
    notifyListeners();
  }

  // ── Safety ───────────────────────────────────────────────────────────────
  Future<void> blockUser(String userId) async {
    _blockedIds.add(userId);
    await prefs?.setStringList('safety.blocked', _blockedIds.toList());
    notifyListeners();
  }

  Future<void> unblockUser(String userId) async {
    _blockedIds.remove(userId);
    await prefs?.setStringList('safety.blocked', _blockedIds.toList());
    notifyListeners();
  }

  bool reportMessage(String messageId, String reason) {
    debugPrint('[unicom:report] message=$messageId reason=$reason');
    return true;
  }

  void deleteMessage(String messageId) {
    _mutate(messageId, (m) => m.copyWith(deleted: true));
    notifyListeners();
  }

  // ── Internals ────────────────────────────────────────────────────────────
  void _put(Message m) {
    final map = _messages.putIfAbsent(
      m.conversationId,
      () => <String, Message>{},
    );
    // Keyed by message id: messageById/_mutate address messages by id and
    // per-recipient translation records are stored on the same canonical row.
    map[m.id] = m;
  }

  void _applyTranslation(String messageId, Translation t) {
    _mutate(messageId, (m) {
      final map = Map<String, Translation>.of(m.translations);
      map[t.targetLanguage] = t;
      return m.copyWith(translations: map);
    });
  }

  void _mutate(String messageId, Message Function(Message) fn) {
    for (final map in _messages.values) {
      final m = map[messageId];
      if (m != null) {
        map[messageId] = fn(m);
        return;
      }
    }
  }

  String _titleCase(String s) =>
      s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1).toLowerCase()}';
}
