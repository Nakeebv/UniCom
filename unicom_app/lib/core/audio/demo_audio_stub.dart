/// Web/stub implementation of the demo audio vault.
///
/// dart:io is unavailable on the web target, so demo voice notes cannot be
/// materialised as files there. Callers treat `null` as "no playable source"
/// and surface an honest unsupported state — playback is never faked.
abstract final class DemoAudioVault {
  static Future<String?> ensureToneFile({
    required String key,
    required Duration duration,
  }) async => null;
}
