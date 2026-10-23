import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:just_audio/just_audio.dart';

import 'demo_audio.dart';

/// Real audio playback for voice notes.
///
/// Wraps just_audio and exposes the small surface the voice bubble needs:
/// play/pause, position/duration, seek, completion, playback speed, and
/// correct disposal. Source resolution:
///
///  • If the payload carries a real recorded file path (mobile recording),
///    that file is played directly.
///  • Seeded demo notes have no server-stored media, so a deterministic
///    low-amplitude tone WAV (matching duration) is generated once in the
///    temp directory and used as the real audio source. This keeps progress
///    and seeking genuine; it is demo content, not simulated speech.
class VoicePlaybackController {
  VoicePlaybackController();

  AudioPlayer? _player;
  StreamSubscription<PlayerState>? _stateSub;
  String? _loadedKey;
  bool _completed = false;

  /// Whether playback finished naturally (drives UI back to idle).
  bool get completed => _completed;

  Duration get _fallbackDuration => const Duration(seconds: 3);

  /// Ensures a player loaded with the given source; returns the total
  /// duration of the actual audio.
  ///
  /// Source priority: [url] (presigned remote asset) → [filePath] (real
  /// recording) → demo tone (offline demo notes).
  Future<Duration> loadSame({
    required String cacheKey,
    required String? filePath,
    required Duration declaredDuration,
    String? url,
    void Function()? onCompleted,
  }) async {
    final key =
        '$cacheKey|${url ?? filePath ?? 'demo'}|${declaredDuration.inMilliseconds}';
    if (_loadedKey == key && _player != null) {
      return _player!.duration ?? declaredDuration;
    }

    await dispose();
    _completed = false;
    _player = AudioPlayer();

    // Remote asset: presigned HTTP(S) URL (works on every platform, no
    // session headers needed — the signature carries the authorization).
    if (url != null && url.startsWith('http')) {
      await _player!.setUrl(url);
      _loadedKey = key;
      _listenCompletion(onCompleted);
      return _player!.duration ?? declaredDuration;
    }

    String? sourcePath = filePath;
    if (sourcePath == null || !sourcePath.startsWith('/')) {
      // Demo note: resolve a real, playable temporary tone file. On web this
      // yields null (dart:io unavailable) — expose an honest unsupported
      // state rather than faking playback.
      sourcePath = await DemoAudioVault.ensureToneFile(
        key: cacheKey,
        duration:
            declaredDuration == Duration.zero
                ? _fallbackDuration
                : declaredDuration,
      );
    }

    if (kIsWeb || sourcePath == null) {
      throw UnsupportedWebAudio();
    }

    await _player!.setFilePath(sourcePath);
    _loadedKey = key;
    _listenCompletion(onCompleted);

    return _player!.duration ?? declaredDuration;
  }

  void _listenCompletion(void Function()? onCompleted) {
    _stateSub = _player!.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        _completed = true;
        onCompleted?.call();
      }
    });
  }

  bool get isPlaying => _player?.playing ?? false;

  Future<void> play() async {
    if (_completed) {
      await _player?.seek(Duration.zero);
      _completed = false;
    }
    await _player?.play();
  }

  Future<void> pause() => _player?.pause() ?? Future.value();

  Future<void> seekFraction(double fraction) async {
    final d = _player?.duration;
    if (d == null || d == Duration.zero) return;
    await _player!.seek(d * fraction.clamp(0.0, 1.0));
  }

  Stream<Duration> positionStream() =>
      _player?.createPositionStream(
        steps: 60,
        minPeriod: const Duration(milliseconds: 60),
        maxPeriod: const Duration(milliseconds: 200),
      ) ??
      const Stream<Duration>.empty();

  Stream<bool> playingStream() =>
      _player?.playerStateStream
          .map(
            (s) => s.playing && s.processingState != ProcessingState.completed,
          )
          .distinct() ??
      const Stream<bool>.empty();

  void setRate(double rate) => _player?.setSpeed(rate.clamp(0.5, 2.0));

  Future<void> dispose() async {
    await _stateSub?.cancel();
    await _player?.dispose();
    _player = null;
    _loadedKey = null;
    _stateSub = null;
  }
}

/// Raised when playback cannot proceed (e.g. web without a playable source).
class UnsupportedWebAudio implements Exception {
  @override
  String toString() =>
      'Audio playback is unavailable in this environment (demo web build).';
}
