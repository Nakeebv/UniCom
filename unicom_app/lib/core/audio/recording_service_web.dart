import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

import 'recording_service.dart';

/// Real browser recording via getUserMedia + MediaRecorder (webm/opus).
///
/// The result carries raw bytes (upload) and a blob: URL (instant preview).
/// Microphone permission is requested on start; an explicit denial surfaces
/// as [MicPermission.denied] so the UI can offer recovery instead of hanging.
class WebRecordingService implements AudioRecordingService {
  web.MediaRecorder? _recorder;
  web.MediaStream? _stream;
  final List<web.Blob> _chunks = [];
  DateTime? _startedAt;
  final StreamController<double> _amps = StreamController<double>.broadcast();
  Timer? _tick;

  @override
  bool get isSupported => true;

  @override
  Future<MicPermission> checkPermission() async => MicPermission.unknown;

  @override
  Future<MicPermission> requestPermission() async {
    try {
      if (_stream == null) {
        _stream = await web.window.navigator.mediaDevices
            .getUserMedia(web.MediaStreamConstraints(audio: true.toJS))
            .toDart;
      }
      return MicPermission.granted;
    } catch (_) {
      return MicPermission.denied;
    }
  }

  @override
  Future<void> start() async {
    if (_stream == null) {
      _stream = await web.window.navigator.mediaDevices
          .getUserMedia(web.MediaStreamConstraints(audio: true.toJS))
          .toDart;
    }
    _chunks.clear();
    _recorder = web.MediaRecorder(_stream!);
    _recorder!.ondataavailable = ((web.BlobEvent e) {
      if (e.data.size > 0) _chunks.add(e.data);
    }).toJS;
    _recorder!.start(250);
    _startedAt = DateTime.now();
    // Lightweight level meter (browser analyser integration pending); the
    // waveform is a live indicator, not analysed audio.
    _tick = Timer.periodic(const Duration(milliseconds: 200), (_) {
      if (!_amps.isClosed) _amps.add(0.55);
    });
  }

  @override
  Stream<double> amplitudes() => _amps.stream;

  @override
  Future<RecordingResult?> stop() async {
    _tick?.cancel();
    final completer = Completer<void>();
    _recorder!.onstop = ((web.Event _) {
      if (!completer.isCompleted) completer.complete();
    }).toJS;
    try {
      _recorder!.stop();
    } catch (_) {
      if (!completer.isCompleted) completer.complete();
    }
    await completer.future
        .timeout(const Duration(seconds: 3), onTimeout: () {});
    final blob = web.Blob(
      _chunks.toJS,
      web.BlobPropertyBag(type: 'audio/webm;codecs=opus'),
    );
    final duration = _startedAt == null
        ? Duration.zero
        : DateTime.now().difference(_startedAt!);
    _stopTracks();
    if (duration.inMilliseconds < 300 || blob.size < 128) return null;
    final bytes = await _blobBytes(blob);
    return RecordingResult(
      duration: duration,
      samples: List<double>.filled(48, 0.6),
      mimeType: 'audio/webm;codecs=opus',
      bytes: bytes,
      blobUrl: web.URL.createObjectURL(blob),
    );
  }

  @override
  Future<void> cancel() async {
    _tick?.cancel();
    try {
      _recorder?.stop();
    } catch (_) {}
    _stopTracks();
  }

  @override
  Future<void> openSystemSettings() async {}

  void _stopTracks() {
    final tracks = _stream?.getTracks().toDart ?? const [];
    for (final t in tracks) {
      t.stop();
    }
    _stream = null;
  }

  Future<Uint8List> _blobBytes(web.Blob blob) async {
    final buffer = await blob.arrayBuffer().toDart;
    return buffer.toDart.asUint8List();
  }
}
