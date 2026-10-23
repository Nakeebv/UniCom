import 'dart:math';

import 'package:flutter/material.dart';

/// The UniCom mark — the brand emblem (glossy blue connection symbol).
///
/// Rendered from the bundled brand asset so app icon, splash, onboarding and
/// auth screens all share one identity. The widget keeps a stable API
/// ([size], [animate], [monochrome], [onSurface]) so existing call sites are
/// unchanged; [monochrome] tints the mark a single ink colour for contexts
/// where full colour is unsuitable, and [onSurface] picks light/dark ink.
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

  static const String assetPath = 'assets/brand/logo_full.png';

  @override
  Widget build(BuildContext context) {
    Widget mark = Image.asset(
      assetPath,
      width: size,
      height: size,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
      // Fallback keeps the UI sane if the asset ever fails to load.
      errorBuilder:
          (_, _, _) => _FallbackMark(size: size, monochrome: monochrome),
      color: monochrome ? _monoInk : null,
      colorBlendMode: monochrome ? BlendMode.srcIn : null,
    );

    if (animate) {
      mark = TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.85, end: 1),
        duration: const Duration(milliseconds: 900),
        curve: Curves.elasticOut,
        builder:
            (context, scale, child) =>
                Transform.scale(scale: scale, child: child),
        child: mark,
      );
    }
    return mark;
  }

  Color get _monoInk =>
      onSurface == LogoSurface.dark ? Colors.white : const Color(0xFF101A1B);
}

enum LogoSurface { dark, light }

/// Drawn fallback used only if the brand asset cannot be decoded.
class _FallbackMark extends StatelessWidget {
  const _FallbackMark({required this.size, required this.monochrome});
  final double size;
  final bool monochrome;

  @override
  Widget build(BuildContext context) {
    final ink =
        monochrome
            ? (Theme.of(context).brightness == Brightness.dark
                ? Colors.white
                : const Color(0xFF101A1B))
            : const Color(0xFF2E6BD6);
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _RingPainter(ink: ink)),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({required this.ink});
  final Color ink;

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.shortestSide / 2;
    final stroke = r * 0.28;
    final paint =
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..strokeCap = StrokeCap.round
          ..color = ink;
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: r - stroke * 0.6),
      -0.6 * pi,
      2 * pi - 1.2 * pi,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) => old.ink != ink;
}
