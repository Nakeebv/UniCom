import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
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
    String? email,
  }) async {
    await session.post(
      '/api/auth/register',
      body: {
        'username': username,
        'displayName': displayName,
        'password': password,
        'preferredLanguage': preferredLanguage,
        if (email != null) 'email': email,
      },
    );
  }

  /// Debounced availability probe used by the signup form. Returns booleans
  /// only (`username_ok` / `email_ok`); nulls for fields not sent.
  /// Uploads (or replaces) the caller's avatar from raw encoded bytes.
  Future<Map<String, dynamic>> uploadAvatarBytes({
    required Uint8List bytes,
    required String mimeType,
  }) async {
    final data = await session.post(
      '/api/me/avatar',
      body: {'base64': base64Encode(bytes), 'mimeType': mimeType},
    );
    return data is Map<String, dynamic> ? data : <String, dynamic>{};
  }

  /// Removes the caller's avatar (reverts to initials).
  Future<void> removeAvatar() => session.delete('/api/me/avatar');

  Future<Map<String, dynamic>> checkAvailability({
    String? username,
    String? email,
  }) async {
    final data = await session.get('/api/users/check', {
      if (username != null && username.isNotEmpty) 'username': username,
      if (email != null && email.isNotEmpty) 'email': email,
    });
    return data is Map<String, dynamic> ? data : <String, dynamic>{};
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

  /// Confirms the emailed 6-digit code. Throws ApiError with the server's
  /// message on an incorrect/expired code so the UI can show it directly.
  Future<bool> verifyEmail(String code) async {
    final data = await session.post(
      '/api/auth/verify-email',
      body: {'code': code},
    );
    return data is Map && data['verified'] == true;
  }

  /// Requests a fresh verification code for the signed-in account.
  Future<void> resendVerificationCode() async {
    await session.post('/api/auth/resend-code');
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
    String? filePath,
    Uint8List? bytes,
    String? mimeType,
    required int durationMs,
  }) async {
    final data = await session.post(
      '/api/media',
      body: {
        'base64': base64Encode(bytes ?? (await File(filePath!).readAsBytes())),
        // Recorder output: .m4a/AAC on mobile, webm/opus on web.
        'mimeType': mimeType ?? 'audio/mp4',
        'durationMs': durationMs,
      },
    );
    if (data is Map && data['asset_id'] is String) {
      return data['asset_id'] as String;
    }
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

  /// Creates a ringing call invitation; the callee is notified over SSE.
  Future<Map<String, dynamic>> inviteCall({
    required String calleeId,
    String callType = 'audio',
  }) async {
    final data = await session.post(
      '/api/calls',
      body: {'calleeId': calleeId, 'callType': callType},
    );
    return data is Map<String, dynamic> ? data : <String, dynamic>{};
  }

  Future<Map<String, dynamic>> getCalls() async {
    final data = await session.get('/api/calls');
    return data is Map<String, dynamic> ? data : <String, dynamic>{};
  }

  Future<Map<String, dynamic>> acceptCall(String callId) async {
    final data = await session.post('/api/calls/$callId/accept');
    return data is Map<String, dynamic> ? data : <String, dynamic>{};
  }

  Future<void> declineCall(String callId) async {
    await session.post('/api/calls/$callId/decline');
  }

  Future<void> endCall(String callId) async {
    await session.post('/api/calls/$callId/end');
  }

  /// Mints a room-scoped LiveKit token server-side (authorization + block
  /// checks happen there). Returns null when calling isn't configured.
  Future<Map<String, dynamic>?> callToken({
    required String peerId,
    required String room,
    String callType = 'audio',
  }) async {
    try {
      final data = await session.post(
        '/api/calls/token',
        body: {'peerId': peerId, 'room': room, 'callType': callType},
      );
      return data is Map<String, dynamic> ? data : null;
    } on ApiError catch (e) {
      if (e.statusCode == 503) return null; // not configured on server
      rethrow;
    }
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
