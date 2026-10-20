import 'dart:math';

import 'package:flutter/material.dart';

import '../../core/theme/palette.dart';

/// The UniCom mark — "speaking together".
///
/// A speech-inspired U: two rounded stems facing each other, each ending in
/// a small speech-bubble tail. The left stem (deep teal) is one speaker,
/// the right stem (brand teal) the other — two-way communication between
/// languages. Drawn as scalable vector artwork; deliberately simple so it
/// stays recognisable at launcher-icon size.
///
/// Variants: full colour by default, [monochrome] for single-ink contexts,
/// and [onSurface] to pick light or dark backdrops (only affects mono ink).
class UniComLogo extends StatelessWidget {
  const UniComLogo({
    super.key,
    this.size = 96,
    this.animate = false,
    this.monochrome = false,
    this.onSurface = LogoSurface.dark,
  });

  final double size;
  final bool animate;
  final bool monochrome;
  final LogoSurface onSurface;

  @override
  Widget build(BuildContext context) {
    final Widget mark = SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _SpeechUPainter(monochrome: monochrome, onSurface: onSurface),
      ),
    );
    if (!animate) return mark;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.85, end: 1),
      duration: const Duration(milliseconds: 900),
      curve: Curves.elasticOut,
      builder:
          (context, scale, child) =>
              Transform.scale(scale: scale, child: child),
      child: mark,
    );
  }
}

enum LogoSurface { dark, light }

class _SpeechUPainter extends CustomPainter {
  _SpeechUPainter({required this.monochrome, required this.onSurface});

  final bool monochrome;
  final LogoSurface onSurface;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    final center = Offset(size.width / 2, size.height / 2);

    final Color leftInk = monochrome ? _monoInk : Palette.tealDeep;
    final Color rightInk = monochrome ? _monoInk : Palette.teal;

    final stroke = s * 0.175;
    final uWidth = s * 0.46; // distance between stem centers
    final top = center.dy - s * 0.30;

    // ── Right stem + bowl half (brand teal) ────────────────────────────────
    final rightPath =
        Path()
          ..moveTo(center.dx + s * 0.04, top)
          ..lineTo(center.dx + s * 0.04, center.dy + s * 0.02)
          ..arcToPoint(
            Offset(center.dx - s * 0.04, center.dy + s * 0.02),
            radius: Radius.circular(s * 0.23),
            clockwise: false,
          );
    final rightStroke =
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..strokeCap = StrokeCap.round
          ..color = rightInk;
    canvas.drawPath(rightPath, rightStroke);

    // Right speech tail: small triangle at the top of the right stem.
    _tail(
      canvas,
      tip: Offset(center.dx + uWidth * 0.52, top - s * 0.10),
      baseA: Offset(center.dx + s * 0.04 + stroke * .32, top + stroke * .28),
      baseB: Offset(center.dx + s * 0.04 + stroke * .92, top - stroke * .30),
      color: rightInk,
    );

    // ── Left stem (deep teal) — slightly shorter, mirrored feel ────────────
    final leftPath =
        Path()
          ..moveTo(center.dx - s * 0.04, top + s * 0.04)
          ..lineTo(center.dx - s * 0.04, center.dy + s * 0.02);
    final leftStroke =
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..strokeCap = StrokeCap.round
          ..color = leftInk;
    canvas.drawPath(leftPath, leftStroke);

    // Left speech tail at the top of the left stem.
    _tail(
      canvas,
      tip: Offset(center.dx - uWidth * 0.52, top - s * 0.04),
      baseA: Offset(center.dx - s * 0.04 - stroke * .32, top + stroke * .3),
      baseB: Offset(center.dx - s * 0.04 - stroke * .92, top - stroke * .26),
      color: leftInk,
    );

    // ── Bowl bottom completing the U (deep teal, joins both stems) ─────────
    final bowl =
        Path()
          ..moveTo(center.dx - s * 0.04, center.dy + s * 0.02)
          ..arcToPoint(
            Offset(center.dx + s * 0.04, center.dy + s * 0.02),
            radius: Radius.circular(s * 0.235),
            clockwise: true,
          );
    canvas.drawPath(bowl, leftStroke..color = leftInk);

    // Small "sound waves" dot: a language spark between the stems.
    final dot = Paint()..color = rightInk;
    canvas.drawCircle(Offset(center.dx, center.dy - s * 0.06), s * 0.045, dot);
  }

  void _tail(
    Canvas canvas, {
    required Offset tip,
    required Offset baseA,
    required Offset baseB,
    required Color color,
  }) {
    final path =
        Path()
          ..moveTo(baseA.dx, baseA.dy)
          ..lineTo(tip.dx, tip.dy)
          ..lineTo(baseB.dx, baseB.dy)
          ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  Color get _monoInk =>
      onSurface == LogoSurface.dark ? Colors.white : const Color(0xFF101A1B);

  @override
  bool shouldRepaint(covariant _SpeechUPainter oldDelegate) =>
      oldDelegate.monochrome != monochrome ||
      oldDelegate.onSurface != onSurface;
}

/// Small deterministic helper used by tests/painters (kept public for reuse).
double logoBowlRadiusFor(double size) => size * 0.23 * pi / pi;
