import 'dart:async';

import 'dart:convert';

import 'package:http/http.dart' as http;

/// Minimal cookie-aware HTTP client for session-based auth.
///
/// The Next.js API authenticates with an HttpOnly session cookie set on
/// login/register. This client stores returned cookies and re-attaches them
/// on subsequent requests to the same host. Cookies are kept in memory only
/// (a logged-out session evaporates with the process).
class UniSession {
  UniSession({required this.baseUrl, http.Client? client})
    : _client = client ?? http.Client();

  final String baseUrl; // e.g. http://10.0.2.2:3000
  final http.Client _client;
  final Map<String, String> _cookies = {};

  Uri _uri(String path, [Map<String, String>? query]) {
    final u = Uri.parse(
      baseUrl.endsWith('/')
          ? baseUrl.substring(0, baseUrl.length - 1)
          : baseUrl,
    );
    return u.replace(path: u.path + path, queryParameters: query);
  }

  void _storeCookies(http.Response res) {
    for (final raw
        in res.headers['set-cookie']?.split(',') ?? const <String>[]) {
      final pair = raw.split(';').first.trim();
      final eq = pair.indexOf('=');
      if (eq <= 0) continue;
      final name = pair.substring(0, eq).trim();
      final value = pair.substring(eq + 1).trim();
      if (value == 'deleted' || value.isEmpty) {
        _cookies.remove(name);
      } else {
        _cookies[name] = value;
      }
    }
  }

  String? get _cookieHeader =>
      _cookies.isEmpty
          ? null
          : _cookies.entries.map((e) => '${e.key}=${e.value}').join('; ');

  Map<String, String> _headers([Map<String, String>? extra]) => {
    'accept': 'application/json',
    if (_cookieHeader != null) 'cookie': _cookieHeader!,
    ...?extra,
  };

  dynamic _decode(http.Response res) {
    if (res.body.isEmpty) return null;
    try {
      return jsonDecode(utf8.decode(res.bodyBytes));
    } catch (_) {
      return null;
    }
  }

  Never _throw(http.Response res) {
    final body = _decode(res);
    final message =
        body is Map && body['error'] is String
            ? body['error'] as String
            : 'http ${res.statusCode}';
    throw ApiError(res.statusCode, message);
  }

  Future<dynamic> get(String path, [Map<String, String>? query]) async {
    final res = await _client.get(_uri(path, query), headers: _headers());
    _storeCookies(res);
    if (res.statusCode >= 400) _throw(res);
    return _decode(res);
  }

  Future<dynamic> post(String path, {Object? body}) async {
    final res = await _client.post(
      _uri(path),
      headers: _headers({'content-type': 'application/json'}),
      body: jsonEncode(body ?? {}),
    );
    _storeCookies(res);
    if (res.statusCode >= 400) _throw(res);
    return _decode(res);
  }

  Future<dynamic> patch(String path, {Object? body}) async {
    final res = await _client.patch(
      _uri(path),
      headers: _headers({'content-type': 'application/json'}),
      body: jsonEncode(body ?? {}),
    );
    _storeCookies(res);
    if (res.statusCode >= 400) _throw(res);
    return _decode(res);
  }

  Future<dynamic> delete(String path) async {
    final res = await _client.delete(_uri(path), headers: _headers());
    _storeCookies(res);
    if (res.statusCode >= 400) _throw(res);
    return _decode(res);
  }

  /// Downloads bytes (audio) with the session cookie attached.
  Future<http.Response> getBytes(
    String path, [
    Map<String, String>? query,
  ]) async {
    final res = await _client.get(_uri(path, query), headers: _headers());
    _storeCookies(res);
    if (res.statusCode >= 400) _throw(res);
    return res;
  }

  /// Opens the SSE stream and yields decoded JSON objects per `data:` line.
  /// Reconnects are the caller's responsibility (see RemoteBackend).
  Stream<Map<String, dynamic>> events(String path) async* {
    while (true) {
      final request = http.Request('GET', _uri(path));
      request.headers.addAll(_headers({'accept': 'text/event-stream'}));
      final response = await _client.send(request);
      if (response.statusCode >= 400) {
        throw ApiError(response.statusCode, 'event stream failed');
      }
      final lines = response.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter());
      await for (final line in lines) {
        if (!line.startsWith('data:')) continue;
        final raw = line.substring(5).trim();
        if (raw.isEmpty) continue;
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) yield decoded;
      }
      await Future<void>.delayed(const Duration(seconds: 2));
    }
  }

  bool get hasSession => _cookies.isNotEmpty;

  void clear() => _cookies.clear();

  /// Reads a presigned URL from the API (which authorizes by session), then
  /// fetches the actual audio bytes from R2 without the session cookie.
  Future<Uri?> resolvePresigned(String mediaPath) async {
    try {
      final data = await get(mediaPath, {'url': '1'});
      final u =
          data is Map && data['url'] is String ? data['url'] as String : null;
      return u == null ? null : Uri.parse(u);
    } on ApiError {
      rethrow;
    }
  }

  void dispose() => _client.close();
}

/// HTTP-level API error with status code, thrown by [UniSession].
class ApiError implements Exception {
  ApiError(this.statusCode, this.message);

  final int statusCode;
  final String message;

  bool get unauthorized => statusCode == 401;
  bool get forbidden => statusCode == 403;

  @override
  String toString() => message;
}

/// Re-thrown on unauthenticated calls so the UI can route to sign-in.
class SessionExpired implements Exception {}
