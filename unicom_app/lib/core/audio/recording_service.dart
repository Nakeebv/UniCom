import 'dart:async';
import 'dart:typed_data';
import 'dart:io';

import 'package:flutter/foundation.dart' show immutable, kIsWeb;
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

/// States of the recording state machine:
/// idle → requestingPermission → recording → stopped → (preview) → sending
/// plus error / cancelled / unsupported exits.
enum RecordingPhase {
  idle,
  requestingPermission,
  recording,
  stopped,
  sending,
  error,
  unsupported,
}

/// Immutable outcome of a completed recording.
@immutable
class RecordingResult {
  const RecordingResult({
    required this.duration,
    required this.samples,
    this.path,
    this.bytes,
    this.mimeType,
    this.blobUrl,
  });

  /// Absolute path of the recorded file (m4a/AAC on mobile). Null on web,
  /// where [bytes]/[blobUrl] carry the audio instead.
  final String? path;
  final Duration duration;
  final List<double> samples;

  /// Raw encoded bytes (web path; also usable on mobile if provided).
  final Uint8List? bytes;
  final String? mimeType;

  /// Blob URL for instant in-page preview (web only).
  final String? blobUrl;
}

enum MicPermission { unknown, granted, denied, permanentlyDenied, unsupported }

/// Contract for microphone capture. Production uses the `record` package
/// (iOS/Android). Web builds expose [isSupported] == false so the UI can
/// present an honest fallback instead of pretending to record.
abstract interface class AudioRecordingService {
  bool get isSupported;
  Future<MicPermission> checkPermission();
  Future<MicPermission> requestPermission();
  Future<void> start();
  Stream<double> amplitudes();
  Future<RecordingResult?> stop();
  Future<void> cancel();
  Future<void> openSystemSettings();
}

/// Real microphone capture via the `record` package.
class NativeRecordingService implements AudioRecordingService {
  NativeRecordingService();

  final AudioRecorder _recorder = AudioRecorder();
  String? _path;
  DateTime? _startedAt;
  Timer? _sampler;
  final StreamController<double> _amplitudes =
      StreamController<double>.broadcast();
  double _lastLevel = 0;

  @override
  bool get isSupported => !kIsWeb && Platform.isAndroid || Platform.isIOS;

  @override
  Future<MicPermission> checkPermission() async {
    try {
      final granted = await _recorder.hasPermission();
      return granted ? MicPermission.granted : MicPermission.denied;
    } catch (_) {
      return MicPermission.denied;
    }
  }

  @override
  Future<MicPermission> requestPermission() async {
    var status = await Permission.microphone.status;
    if (status.isGranted) return MicPermission.granted;
    if (status.isPermanentlyDenied || status.isRestricted) {
      return MicPermission.permanentlyDenied;
    }
    status = await Permission.microphone.request();
    if (status.isGranted) return MicPermission.granted;
    if (status.isPermanentlyDenied) return MicPermission.permanentlyDenied;
    return MicPermission.denied;
  }

  @override
  Future<void> start() async {
    if (kIsWeb || !(Platform.isAndroid || Platform.isIOS)) {
      throw UnsupportedError('Microphone capture requires iOS or Android');
    }
    _path =
        '${Directory.systemTemp.path}/unicom_voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
    _startedAt = DateTime.now();
    await _recorder.start(
      const RecordConfig(encoder: AudioEncoder.aacLc, bitRate: 96000),
      path: _path!,
    );
    // Poll actual input levels (record exposes a stream, but polling the API
    // keeps sampling consistent across versions).
    _sampler = Timer.periodic(const Duration(milliseconds: 120), (_) async {
      try {
        final amp = await _recorder.getAmplitude();
        // record returns currentAmplitude in dBFS (-inf..0); map -60..0 → 0..1
        final db = amp.current.clamp(-60.0, 0.0);
        _lastLevel = ((db + 60) / 60).clamp(0.0, 1.0);
      } catch (_) {
        _lastLevel *= .8;
      }
      _amplitudesHistory.add(_lastLevel);
      if (_amplitudesHistory.length > 512) _amplitudesHistory.removeAt(0);
      if (!_amplitudes.isClosed) _amplitudes.add(_lastLevel);
    });
  }

  @override
  Stream<double> amplitudes() => _amplitudes.stream;

  @override
  Future<RecordingResult?> stop() async {
    _sampler?.cancel();
    final stoppedPath = await _recorder.stop();
    final duration =
        _startedAt == null
            ? Duration.zero
            : DateTime.now().difference(_startedAt!);
    final samples = _collectedSamples();
    if (stoppedPath == null || duration.inMilliseconds < 300) {
      _cleanup(stoppedPath ?? _path);
      return null;
    }
    _path = null;
    _startedAt = null;
    return RecordingResult(
      path: stoppedPath,
      duration: duration,
      samples: samples,
    );
  }

  @override
  Future<void> cancel() async {
    _sampler?.cancel();
    try {
      final p = await _recorder.stop();
      _cleanup(p ?? _path);
    } catch (_) {
      _cleanup(_path);
    }
    _path = null;
    _startedAt = null;
  }

  @override
  Future<void> openSystemSettings() => openAppSettings();

  List<double> _collectedSamples() {
    // Deterministic downsample of the captured level history into a
    // 48-point envelope for the waveform view.
    final List<double> captured = _amplitudesHistory.toList();
    const n = 48;
    final rnd = <double>[];
    if (captured.isEmpty) {
      for (var i = 0; i < n; i++) {
        rnd.add(0.45 + 0.35 * (i.isEven ? 1 : .7));
      }
      return rnd;
    }
    for (var i = 0; i < n; i++) {
      final idx = (i * captured.length / n).floor().clamp(
        0,
        captured.length - 1,
      );
      rnd.add(captured[idx].clamp(.12, 1.0));
    }
    return rnd;
  }

  final List<double> _amplitudesHistory = <double>[];

  void _cleanup(String? p) {
    if (p == null) return;
    try {
      final f = File(p);
      if (f.existsSync()) f.deleteSync();
    } catch (_) {
      /* best effort */
    }
  }

  void dispose() {
    _sampler?.cancel();
    _amplitudes.close();
  }
}

/// Web / unsupported-platform stub that never pretends to record.
class UnsupportedRecordingService implements AudioRecordingService {
  @override
  bool get isSupported => false;

  @override
  Future<MicPermission> checkPermission() async => MicPermission.unsupported;

  @override
  Future<MicPermission> requestPermission() async => MicPermission.unsupported;

  @override
  Future<void> start() =>
      throw UnsupportedError('Recording needs a mobile device');

  @override
  Stream<double> amplitudes() => const Stream<double>.empty();

  @override
  Future<RecordingResult?> stop() async => null;

  @override
  Future<void> cancel() async {}

  @override
  Future<void> openSystemSettings() async {}
}
