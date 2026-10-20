/// Conditional entry point for the demo audio vault.
///
///  • IO targets (iOS / Android / desktop): `demo_audio_io.dart` materialises
///    a real WAV file for seeded demo voice notes so playback, seeking and
///    completion are genuine.
///  • Web: `demo_audio_stub.dart` returns no source; the UI presents an
///    honest "playback unavailable in the web demo" state.
export 'demo_audio_stub.dart' if (dart.library.io) 'demo_audio_io.dart';

/// Shared helper mirroring the vault contract for callers.
typedef DemoAudioVaultResult = Future<String?>;
