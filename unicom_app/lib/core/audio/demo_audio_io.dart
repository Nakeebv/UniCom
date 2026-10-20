import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

// IO implementation — see demo_audio.dart for the conditional entry point.

/// IO implementation of the demo audio vault (see demo_audio.dart).
///
/// UniCom's demo world has no server-stored media, so seeded notes need
/// *something* real to play. We synthesise a short low-amplitude tone —
/// deliberately quiet and unmistakably synthetic (never mistaken for real
/// speech) — with a duration that matches the note's metadata, so playback
/// progress, seeking and completion behave like production audio.
///
/// Newly *recorded* voice notes bypass this entirely: their actual recorded
/// file is played back.
abstract final class DemoAudioVault {
  static const int sampleRate = 8000; // mono 16-bit — tiny files

  /// Creates (idempotently) a demo WAV for [key] with the given [duration]
  /// and returns its absolute path.
  static Future<String?> ensureToneFile({
    required String key,
    required Duration duration,
  }) async {
    final safeName = key.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    final path = '${Directory.systemTemp.path}/unicom_demo_$safeName.wav';
    final f = File(path);
    if (f.existsSync() && f.lengthSync() > 44) return path;

    final bytes = _synthToneWav(
      duration:
          duration.isNegative || duration.inMilliseconds < 300
              ? const Duration(milliseconds: 1200)
              : duration,
    );
    await f.writeAsBytes(bytes, flush: true);
    return path;
  }

  /// Mono 16-bit PCM WAV containing a soft, low-amplitude two-tone hum.
  static Uint8List _synthToneWav({required Duration duration}) {
    final totalSamples = (duration.inMilliseconds * sampleRate ~/ 1000).clamp(
      sampleRate ~/ 2,
      sampleRate * 600,
    ); // 0.5s .. 10min
    final data = BytesBuilder();

    // RIFF header
    final byteLen = totalSamples * 2;
    data.add(_ascii('RIFF'));
    data.add(_u32(36 + byteLen));
    data.add(_ascii('WAVE'));
    data.add(_ascii('fmt '));
    data.add(_u32(16)); // PCM chunk size
    data.add(_u16(1)); // PCM format
    data.add(_u16(1)); // mono
    data.add(_u32(sampleRate));
    data.add(_u32(sampleRate * 2)); // byte rate
    data.add(_u16(2)); // block align
    data.add(_u16(16)); // bits/sample
    data.add(_ascii('data'));
    data.add(_u32(byteLen));

    // Samples: gentle 196Hz + 262Hz hum with a fade envelope. Quiet on
    // purpose (~10% amplitude) so it never masquerades as real speech.
    const amp = 0.10;
    for (var i = 0; i < totalSamples; i++) {
      final t = i / sampleRate;
      final fade = min(
        1.0,
        min(i / (sampleRate * .05), (totalSamples - i) / (sampleRate * .05)),
      );
      final v =
          amp *
          fade *
          (0.6 * sin(2 * pi * 196 * t) + 0.4 * sin(2 * pi * 262 * t));
      final s = (v * 32767).round().clamp(-32768, 32767);
      data.add(_s16(s));
    }
    return data.toBytes();
  }

  static List<int> _ascii(String s) => s.codeUnits;
  static List<int> _u32(int v) => [
    v & 255,
    (v >> 8) & 255,
    (v >> 16) & 255,
    (v >> 24) & 255,
  ];
  static List<int> _u16(int v) => [v & 255, (v >> 8) & 255];
  static List<int> _s16(int v) => [v & 255, (v >> 8) & 255];
}
