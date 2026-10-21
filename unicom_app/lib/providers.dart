import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'data/api/remote_backend.dart';
import 'data/backend_base.dart';
import 'data/demo/mock_backend.dart';

/// Which backend the app talks to.
///
///  • Mock (default): the offline demo world — zero config, simulated MT/STT.
///  • Remote: the real Next.js API (session cookies, per-recipient
///    translations, R2 media, Whisper STT, MeloTTS). Host via:
///      flutter run --dart-define=UNICOM_BASE_URL=http://10.0.2.2:3000
///    (10.0.2.2 = host loopback from the Android emulator; use your LAN IP on
///    physical devices. On web builds any http origin needs CORS on the API.)
const String _kBaseUrl = String.fromEnvironment('UNICOM_BASE_URL');

final bool useRemoteBackend = _kBaseUrl.isNotEmpty;

/// Single backend instance for the whole app. Screens depend only on
/// [UniBackend], so both modes are interchangeable.
final backendProvider = ChangeNotifierProvider<UniBackend>((ref) {
  if (useRemoteBackend) {
    return RemoteBackend(baseUrl: _kBaseUrl);
  }
  return MockBackend();
});

/// Convenience selectors (still fine to watch the backend directly).
final conversationsProvider = Provider<List<Conversation>>((ref) {
  final backend = ref.watch(backendProvider);
  return backend.conversations;
});

final themeModeProvider = Provider<ThemeMode>((ref) {
  return ref.watch(backendProvider).themeMode;
});

final myProfileProvider = Provider((ref) => ref.watch(backendProvider).me);

/// Convenience extension for screens that need the concrete demo backend in
/// mock mode (e.g. polls, which have no live API contract yet).
extension BackendX on UniBackend {
  MockBackend? get asMock => this is MockBackend ? this as MockBackend : null;
  RemoteBackend? get asRemote =>
      this is RemoteBackend ? this as RemoteBackend : null;

  Timer? get debugTimer => null;
}
