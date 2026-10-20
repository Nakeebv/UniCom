import 'dart:async';

import 'package:flutter/material.dart';

/// Waveform bar sequence with a playhead and optional tap-to-seek.
///
/// Playback progress can either be simulated (no audio source — the visual
/// demo path still behaves like a player) or driven by a real player via
/// [position]. When [position] is non-null the internal timer is bypassed
/// and [onSeek] receives tap fractions across the waveform strip.
class WaveformView extends StatefulWidget {
  const WaveformView({
    super.key,
    required this.samples,
    required this.duration,
    this.color,
    this.playedColor,
    this.playing = false,
    this.onToggle,
    this.speed = 1.0,
    this.bars = 34,
    this.compact = false,
    this.position,
    this.onSeek,
  });

  final List<double> samples;
  final Duration duration;
  final Color? color;
  final Color? playedColor;
  final bool playing;
  final VoidCallback? onToggle;
  final double speed;
  final int bars;
  final bool compact;

  /// Real player position. Non-null ⇒ external progress mode.
  final Duration? position;

  /// Called with 0..1 when the user taps the waveform (external mode only).
  final ValueChanged<double>? onSeek;

  @override
  State<WaveformView> createState() => _WaveformViewState();
}

class _WaveformViewState extends State<WaveformView> {
  double _simProgress = 0;
  Timer? _timer;

  static const Duration _realtimeTick = Duration(milliseconds: 60);

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  bool get _external => widget.position != null;

  double get _progress {
    if (_external) {
      final totalMs = widget.duration.inMilliseconds;
      if (totalMs <= 0) return 0;
      return (widget.position!.inMilliseconds / totalMs).clamp(0.0, 1.0);
    }
    return _simProgress;
  }

  void _ensureTimer() {
    _timer?.cancel();
    if (widget.playing && !_external) {
      final step = _realtimeTick * (widget.speed == 0 ? 1.0 : widget.speed);
      final totalMs = widget.duration.inMilliseconds.clamp(400, 3600000);
      _timer = Timer.periodic(step, (t) {
        setState(() {
          _simProgress += step.inMilliseconds / totalMs;
          if (_simProgress >= 1) {
            _simProgress = 0;
            t.cancel();
            widget.onToggle?.call();
          }
        });
      });
    }
  }

  @override
  void didUpdateWidget(covariant WaveformView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.playing != widget.playing ||
        oldWidget.speed != widget.speed) {
      _ensureTimer();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _PlayButton(
          playing: widget.playing,
          color: widget.playedColor ?? Theme.of(context).colorScheme.primary,
          size: widget.compact ? 34 : 40,
          onTap: widget.onToggle,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: LayoutBuilder(
            builder: (context, box) {
              // Wave strip occupies the middle; account for the play button
              // (size + 10 gutter) and trailing clock gutter (~44) on tap.
              final lead = (widget.compact ? 34 : 40) + 10;
              final trail = 44.0;
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapUp: (d) {
                  if (!_external) return;
                  final frac = ((d.localPosition.dx - lead) /
                          (box.maxWidth - lead - trail))
                      .clamp(0.0, 1.0);
                  widget.onSeek?.call(frac);
                },
                child: SizedBox(
                  height: widget.compact ? 30 : 36,
                  child: CustomPaint(
                    painter: _WavePainter(
                      samples: widget.samples,
                      bars: widget.bars,
                      progress: _progress,
                      base:
                          widget.color ??
                          Theme.of(
                            context,
                          ).colorScheme.onSurfaceVariant.withValues(alpha: .38),
                      played:
                          widget.playedColor ??
                          Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 38,
          child: Text(
            _clock(),
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }

  String _clock() {
    final real = widget.duration;
    if (real == Duration.zero) return '00:00';
    final playedMs = _progress * real.inMilliseconds;
    final shown =
        widget.playing || _progress > 0
            ? Duration(milliseconds: playedMs.round())
            : real;
    final m = shown.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = shown.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}

class _PlayButton extends StatelessWidget {
  const _PlayButton({
    required this.playing,
    required this.color,
    required this.size,
    this.onTap,
  });

  final bool playing;
  final Color color;
  final double size;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: .14),
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: size,
          height: size,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            child: Icon(
              playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
              key: ValueKey(playing),
              color: color,
              size: size * 0.62,
            ),
          ),
        ),
      ),
    );
  }
}

class _WavePainter extends CustomPainter {
  _WavePainter({
    required this.samples,
    required this.bars,
    required this.progress,
    required this.base,
    required this.played,
  });

  final List<double> samples;
  final int bars;
  final double progress;
  final Color base;
  final Color played;

  @override
  void paint(Canvas canvas, Size size) {
    final n = bars;
    const gap = 2.4;
    final barW = (size.width - (n - 1) * gap) / n;
    final paint = Paint()..strokeCap = StrokeCap.round;
    final playedIdx = progress * n;

    for (var i = 0; i < n; i++) {
      final sample =
          samples[(i * samples.length / n).floor().clamp(
            0,
            samples.length - 1,
          )];
      final h = (0.22 + sample * 0.78) * size.height;
      final x = i * (barW + gap);
      final y = (size.height - h) / 2;
      paint.color =
          i <= playedIdx - .4
              ? (i == (playedIdx - .4).floor() && progress < 1
                  ? Color.lerp(base, played, playedIdx - .4 - i) ?? played
                  : played)
              : base;
      // Emphasis swell around the playhead
      final dist = (i - playedIdx).abs();
      final swell = dist < 1.4 ? (1.4 - dist) * 2.4 : 0;
      final rrect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, y - swell / 2, barW, h + swell),
        Radius.circular(barW / 2),
      );
      canvas.drawRRect(rrect, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _WavePainter old) =>
      old.progress != progress ||
      old.base != base ||
      old.played != played ||
      !identical(old.samples, samples);
}
