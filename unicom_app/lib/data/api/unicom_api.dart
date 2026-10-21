import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../models/message.dart';
import 'uni_session.dart';

/// Typed UniCom REST client (contract: `src/app/api/**`).
///
/// All methods return decoded JSON maps; the RemoteBackend layer maps them
/// onto the app models so widget code never sees wire shapes.
class UniComApi {
  UniComApi(this.session);

  UniSession session;

  // ── Auth ─────────────────────────────────────────────────────────────────
  Future<void> register({
    required String username,
    required String displayName,
    required String password,
    required String preferredLanguage,
  }) async {
    await session.post(
      '/api/auth/register',
      body: {
        'username': username,
        'displayName': displayName,
        'password': password,
        'preferredLanguage': preferredLanguage,
      },
    );
  }

  Future<void> login({
    required String username,
    required String password,
  }) async {
    await session.post(
      '/api/auth/login',
      body: {'username': username, 'password': password},
    );
  }

  Future<void> logout() async {
    try {
      await session.post('/api/auth/logout');
    } finally {
      session.clear();
    }
  }

  /// Throws [ApiError] 401 when no session.
  Future<Map<String, dynamic>?> me() async {
    try {
      final data = await session.get('/api/me');
      return data is Map ? (data['me'] as Map<String, dynamic>?) : null;
    } on ApiError catch (e) {
      if (e.unauthorized) session.clear();
      rethrow;
    }
  }

  Future<void> patchMe({
    String? preferredLanguage,
    String? speechLanguage,
    String? displayName,
  }) {
    return session.patch(
      '/api/me',
      body: {
        if (preferredLanguage != null) 'preferredLanguage': preferredLanguage,
        if (speechLanguage != null) 'speechLanguage': speechLanguage,
        if (displayName != null) 'displayName': displayName,
      },
    );
  }

  Future<void> uploadAvatar({required String filePath}) async {
    final bytes = await File(filePath).readAsBytes();
    final ext =
        filePath.toLowerCase().endsWith('.png')
            ? 'image/png'
            : filePath.toLowerCase().endsWith('.webp')
            ? 'image/webp'
            : 'image/jpeg';
    await session.post(
      '/api/me/avatar',
      body: {'base64': base64Encode(bytes), 'mimeType': ext},
    );
  }

  // ── Directory ────────────────────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> contacts() async {
    final data = await session.get('/api/contacts');
    final list =
        data is Map && data['contacts'] is List
            ? data['contacts'] as List
            : const [];
    return list.whereType<Map<String, dynamic>>().toList();
  }

  // ── Conversations & messages ─────────────────────────────────────────────
  Future<Map<String, dynamic>> sync({String? since}) async {
    final data = await session.get(
      '/api/sync',
      since == null ? null : {'since': since},
    );
    return data is Map<String, dynamic> ? data : <String, dynamic>{};
  }

  Future<Map<String, dynamic>> openConversation(String otherUserId) {
    return (session.post(
          '/api/conversations',
          body: {
            'memberIds': [otherUserId],
          },
        )
        as Future<Map<String, dynamic>>);
  }

  Future<Map<String, dynamic>> createGroup(
    String title,
    List<String> memberIds,
  ) {
    return (session.post(
          '/api/conversations',
          body: {'memberIds': memberIds, 'title': title},
        )
        as Future<Map<String, dynamic>>);
  }

  Future<List<Map<String, dynamic>>> messages(String conversationId) async {
    final data = await session.get(
      '/api/conversations/$conversationId/messages',
    );
    final list =
        data is Map && data['messages'] is List
            ? data['messages'] as List
            : const [];
    return list.whereType<Map<String, dynamic>>().toList();
  }

  Future<Map<String, dynamic>> messagesBefore(
    String conversationId,
    String beforeIso,
  ) async {
    final data = await session.get(
      '/api/conversations/$conversationId/messages',
      {'before': beforeIso},
    );
    return data is Map<String, dynamic> ? data : <String, dynamic>{};
  }

  Future<void> markRead(String conversationId) {
    return (session.post('/api/conversations/$conversationId/read')
        as Future<void>);
  }

  Future<void> sendText({
    required String conversationId,
    required String text,
    required String sourceLanguage,
    required String clientId,
  }) {
    return (session.post(
          '/api/conversations/$conversationId/messages',
          body: {
            'type': 'text',
            'text': text,
            'sourceLanguage': sourceLanguage,
            'clientId': clientId,
          },
        )
        as Future<void>);
  }

  Future<String> uploadVoice({
    required String filePath,
    required int durationMs,
  }) async {
    final bytes = await File(filePath).readAsBytes();
    final data = await session.post(
      '/api/media',
      body: {
        'base64': base64Encode(bytes),
        // The recorder produces .m4a (AAC) on iOS and Android.
        'mimeType': 'audio/mp4',
        'durationMs': durationMs,
      },
    );
    if (data is Map && data['asset_id'] is String)
      return data['asset_id'] as String;
    throw ApiError(500, 'media upload returned no asset id');
  }

  Future<void> sendVoice({
    required String conversationId,
    required String mediaAssetId,
    required String sourceLanguage,
    required String clientId,
  }) {
    return (session.post(
          '/api/conversations/$conversationId/messages',
          body: {
            'type': 'voice',
            'mediaAssetId': mediaAssetId,
            'sourceLanguage': sourceLanguage,
            'clientId': clientId,
          },
        )
        as Future<void>);
  }

  Future<void> retryTranslation(String messageId) {
    return (session.post('/api/messages/$messageId/translations')
        as Future<void>);
  }

  Future<void> deleteMessage(String messageId) {
    return (session.delete('/api/messages/$messageId') as Future<void>);
  }

  Future<void> report(String messageId, String reason) {
    return (session.post(
          '/api/messages/$messageId/reports',
          body: {'reason': reason},
        )
        as Future<void>);
  }

  Future<void> setBlocked({required String userId, required bool blocked}) {
    if (blocked) {
      return (session.post('/api/users/$userId/block') as Future<void>);
    }
    return (session.delete('/api/users/$userId/block') as Future<void>);
  }

  Future<void> typing(String conversationId) {
    return (session.post(
          '/api/typing',
          body: {'conversationId': conversationId},
        )
        as Future<void>);
  }

  Future<void> dispose() => Future<void>.value();
}

/// Deterministic waveform for wire messages (visual-only, labelled in UI).
List<double> waveformForSeed(String seed, [int n = 44]) =>
    Message.seededWaveform(seed, n);
