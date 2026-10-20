import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/audio/playback_service.dart';
import '../../../core/audio/recording_service.dart';
import '../../../core/theme/palette.dart';
import '../../../core/utils.dart';

/// Full-screen recording experience backed by the [AudioRecordingService].
///
/// State machine:
/// `idle → requestingPermission → recording → stopped(preview) → sending`
/// with `error`, `cancelled`, and `unsupported` exits. The user can stop,
/// replay the actual recorded file, discard, or send. Nothing is reported
/// as "sent" until the caller's send completes (invoked via [onSend]).
class RecorderOverlay extends StatefulWidget {
  const RecorderOverlay({
    super.key,
    required this.onSend,
    this.service,
    this.demoFallback,
  });

  /// Invoked only after the user confirms send with a real recording on the
  /// stack — or via the clearly-labelled demo fallback where recording is
  /// unavailable (web).
  final Future<void> Function(RecordingResult result) onSend;

  /// Clearly-labelled simulation used only when real capture is unsupported
  /// (web demo build). Receives the intended duration so the seeded pipeline
  /// still exercises the real processing stages.
  final Future<void> Function(Duration duration)? demoFallback;

  final AudioRecordingService? service;

  @override
  State<RecorderOverlay> createState() => _RecorderOverlayState();
}

class _RecorderOverlayState extends State<RecorderOverlay>
    with SingleTickerProviderStateMixin {
  late final AudioRecordingService _service =
      widget.service ?? NativeRecordingService();

  RecordingPhase _phase = RecordingPhase.idle;
  String? _error;
  Timer? _clock;
  Duration _elapsed = Duration.zero;
  RecordingResult? _result;

  VoicePlaybackController? _preview;
  StreamSubscription<double>? _ampSub;
  double _level = 0;
  final List<double> _levels = [];

  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );

  @override
  void initState() {
    super.initState();
    _begin();
  }

  Future<void> _begin() async {
    if (!_service.isSupported) {
      setState(() => _phase = RecordingPhase.unsupported);
      return;
    }
    setState(() => _phase = RecordingPhase.requestingPermission);
    var permission = await _service.checkPermission();
    if (permission == MicPermission.denied ||
        permission == MicPermission.unknown) {
      permission = await _service.requestPermission();
    }
    if (!mounted) return;
    if (permission == MicPermission.permanentlyDenied) {
      setState(() => _phase = RecordingPhase.error);
      setState(
        () =>
            _error =
                'Microphone access is blocked for UniCom. Enable it in Settings to '
                'record voice notes.',
      );
      return;
    }
    if (permission != MicPermission.granted) {
      setState(() {
        _phase = RecordingPhase.error;
        _error = 'Microphone permission was not granted.';
      });
      return;
    }

    try {
      await _service.start();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _phase = RecordingPhase.error;
        _error = 'Could not start recording: $e';
      });
      return;
    }
    _ampSub = _service.amplitudes().listen((level) {
      if (!mounted) return;
      setState(() {
        _level = level;
        _levels.add(level);
        if (_levels.length > 64) _levels.removeAt(0);
      });
    });
    setState(() => _phase = RecordingPhase.recording);
    _pulse.repeat(reverse: true);
    _clock = Timer.periodic(const Duration(milliseconds: 200), (t) {
      if (mounted)
        setState(() => _elapsed += const Duration(milliseconds: 200));
    });
  }

  Future<void> _stop() async {
    _clock?.cancel();
    _pulse.stop();
    await _ampSub?.cancel();
    try {
      final result = await _service.stop();
      if (!mounted) return;
      if (result == null) {
        setState(() {
          _phase = RecordingPhase.error;
          _error = 'Recording was too short. Hold the mic and try again.';
        });
        return;
      }
      _result = result;
      setState(() => _phase = RecordingPhase.stopped);
      await _preparePreview();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _phase = RecordingPhase.error;
        _error = 'Failed to save recording: $e';
      });
    }
  }

  Future<void> _preparePreview() async {
    final r = _result;
    if (r == null || r.path == null) return;
    try {
      final controller = VoicePlaybackController();
      await controller.loadSame(
        cacheKey: 'preview-${r.path}',
        filePath: r.path,
        declaredDuration: r.duration,
      );
      _preview = controller;
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) {
        setState(() => _error = 'Preview unavailable: $e');
      }
    }
  }

  Future<void> _replayPreview() async {
    await _preview?.play();
    if (mounted) setState(() {});
  }

  Future<void> _send() async {
    final r = _result;
    if (r == null) return;
    setState(() => _phase = RecordingPhase.sending);
    await _preview?.dispose();
    _preview = null;
    await widget.onSend(r);
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _cancel() async {
    _clock?.cancel();
    _pulse.stop();
    await _ampSub?.cancel();
    await _service.cancel();
    await _preview?.dispose();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _clock?.cancel();
    _ampSub?.cancel();
    _pulse.dispose();
    _preview?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xE6060B0C),
      body: SafeArea(
        child: switch (_phase) {
          RecordingPhase.unsupported => _unsupportedView(),
          RecordingPhase.error => _errorView(),
          RecordingPhase.requestingPermission => const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: Palette.teal),
                SizedBox(height: 16),
                Text(
                  'Checking microphone permission…',
                  style: TextStyle(color: Palette.textSecondary),
                ),
              ],
            ),
          ),
          RecordingPhase.recording => _recordingView(),
          RecordingPhase.stopped => _previewView(),
          RecordingPhase.sending => const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: Palette.teal),
                SizedBox(height: 16),
                Text(
                  'Uploading your voice note…',
                  style: TextStyle(color: Palette.textSecondary),
                ),
              ],
            ),
          ),
          RecordingPhase.idle => const SizedBox.shrink(),
        },
      ),
    );
  }

  // ── Views ────────────────────────────────────────────────────────────────

  Widget _unsupportedView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 78,
              height: 78,
              decoration: const BoxDecoration(
                color: Palette.orangeSoft,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.mic_off_rounded,
                color: Palette.orange,
                size: 32,
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Recording needs the mobile app',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Palette.textPrimary,
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'This web demo has no microphone access. You can still send a '
              'labelled demo voice note that walks through the real '
              'translate-then-speak pipeline.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Palette.textSecondary,
                fontSize: 13,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 22),
            if (widget.demoFallback != null)
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: Palette.teal,
                  foregroundColor: const Color(0xFF06211F),
                ),
                onPressed: () async {
                  Navigator.of(context).pop();
                  await widget.demoFallback!(const Duration(seconds: 5));
                },
                child: const Text('Send labelled demo note'),
              ),
            const SizedBox(height: 8),
            TextButton(onPressed: _cancel, child: const Text('Cancel')),
          ],
        ),
      ),
    );
  }

  Widget _errorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 78,
              height: 78,
              decoration: const BoxDecoration(
                color: Palette.dangerSoft,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.error_outline_rounded,
                color: Palette.danger,
                size: 32,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              _error ?? 'Something went wrong.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Palette.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w700,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton(
                  onPressed: () {
                    setState(() {
                      _phase = RecordingPhase.idle;
                      _error = null;
                      _elapsed = Duration.zero;
                      _result = null;
                      _levels.clear();
                    });
                    _begin();
                  },
                  child: const Text('Try again'),
                ),
                const SizedBox(width: 12),
                TextButton(onPressed: _cancel, child: const Text('Close')),
              ],
            ),
            if (_phase == RecordingPhase.error &&
                _error != null &&
                _error!.contains('blocked')) ...[
              const SizedBox(height: 6),
              TextButton(
                onPressed: _service.openSystemSettings,
                child: const Text('Open system settings'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _recordingView() {
    return Column(
      children: [
        Row(
          children: [
            IconButton(
              onPressed: _cancel,
              tooltip: 'Cancel recording',
              icon: const Icon(Icons.close_rounded, color: Colors.white70),
            ),
            const Spacer(),
            Text(
              formatDuration(_elapsed),
              style: const TextStyle(
                color: Palette.textPrimary,
                fontSize: 17,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.5,
              ),
            ),
            const Spacer(),
            const SizedBox(width: 48),
          ],
        ),
        const Padding(
          padding: EdgeInsets.only(top: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.fiber_manual_record, color: Palette.danger, size: 10),
              SizedBox(width: 6),
              Text(
                'REC · tap stop to preview',
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.1,
                ),
              ),
            ],
          ),
        ),
        const Spacer(flex: 3),
        Stack(
          alignment: Alignment.center,
          children: [
            FadeTransition(
              opacity: _pulse,
              child: Container(
                width: 190,
                height: 190,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Palette.danger.withValues(alpha: .5),
                    width: 2,
                  ),
                ),
              ),
            ),
            ScaleTransition(
              scale: Tween(
                begin: .96 + .04 * _level,
                end: 1.02 + .05 * _level,
              ).animate(
                CurvedAnimation(parent: _pulse, curve: Curves.easeInOut),
              ),
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Palette.danger, Color(0xFFB23A4A)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Palette.danger.withValues(
                        alpha: .25 + .25 * _level,
                      ),
                      blurRadius: 34,
                      spreadRadius: 4,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.mic_rounded,
                  color: Colors.white,
                  size: 44,
                  semanticLabel: 'Recording',
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 30),
        _LiveBars(levels: _levels, level: _level),
        const SizedBox(height: 10),
        const Text(
          'Speech is transcribed, translated and spoken back in your '
          'recipient\'s language',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white54,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const Spacer(flex: 4),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                children: [
                  _Ctl(icon: Icons.delete_outline_rounded, onTap: _cancel),
                  const SizedBox(height: 6),
                  const Text(
                    'Cancel',
                    style: TextStyle(color: Colors.white60, fontSize: 11.5),
                  ),
                ],
              ),
              Column(
                children: [
                  _Ctl(
                    icon: Icons.stop_rounded,
                    filled: true,
                    onTap: _phase == RecordingPhase.recording ? _stop : null,
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Stop',
                    style: TextStyle(color: Colors.white60, fontSize: 11.5),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 46),
      ],
    );
  }

  Widget _previewView() {
    final r = _result!;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
          child: Row(
            children: [
              const Icon(
                Icons.check_circle_outline_rounded,
                color: Palette.online,
                size: 18,
              ),
              const SizedBox(width: 8),
              const Text(
                'Recording ready',
                style: TextStyle(
                  color: Palette.textPrimary,
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
              ),
              const Spacer(),
              Text(
                formatDuration(r.duration),
                style: const TextStyle(
                  color: Palette.textSecondary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 26),
        GestureDetector(
          onTap: _replayPreview,
          child: Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              gradient: Palette.brand,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.play_arrow_rounded,
              color: Color(0xFF06211F),
              size: 44,
              semanticLabel: 'Replay recording',
            ),
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          'Replay before sending',
          style: TextStyle(color: Palette.textSecondary, fontSize: 12),
        ),
        const Spacer(),
        Padding(
          padding: const EdgeInsets.fromLTRB(28, 0, 28, 26),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Palette.danger,
                    side: const BorderSide(color: Palette.danger),
                    minimumSize: const Size(0, 52),
                  ),
                  onPressed: () async {
                    await _preview?.dispose();
                    _preview = null;
                    setState(() {
                      _result = null;
                      _phase = RecordingPhase.idle;
                      _elapsed = Duration.zero;
                      _levels.clear();
                    });
                    _begin();
                  },
                  child: const Text('Discard'),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: Palette.teal,
                    foregroundColor: const Color(0xFF06211F),
                    minimumSize: const Size(0, 52),
                  ),
                  onPressed: _send,
                  child: const Text('Send'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Ctl extends StatelessWidget {
  const _Ctl({required this.icon, this.onTap, this.filled = false});

  final IconData icon;
  final VoidCallback? onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          color: filled ? Palette.danger : Colors.white.withValues(alpha: .1),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 26),
      ),
    );
  }
}

class _LiveBars extends StatelessWidget {
  const _LiveBars({required this.levels, required this.level});

  final List<double> levels;
  final double level;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 230,
      height: 44,
      child: CustomPaint(
        painter: _LiveBarsPainter(levels: levels, level: level),
      ),
    );
  }
}

class _LiveBarsPainter extends CustomPainter {
  _LiveBarsPainter({required this.levels, required this.level});
  final List<double> levels;
  final double level;

  @override
  void paint(Canvas canvas, Size size) {
    const n = 26;
    const gap = 2.6;
    final barW = (size.width - (n - 1) * gap) / n;
    final paint = Paint()..strokeCap = StrokeCap.round;
    for (var i = 0; i < n; i++) {
      final sample =
          levels.isEmpty
              ? 0.3
              : levels[(i * levels.length / n).floor().clamp(
                0,
                levels.length - 1,
              )];
      final h = (0.2 + sample * 0.8) * size.height;
      paint.color = Palette.orange.withValues(alpha: .35 + .65 * sample);
      final rrect = RRect.fromRectAndRadius(
        Rect.fromLTWH(i * (barW + gap), (size.height - h) / 2, barW, h),
        Radius.circular(barW / 2),
      );
      canvas.drawRRect(rrect, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _LiveBarsPainter old) =>
      old.level != level || !identical(old.levels, levels);
}
