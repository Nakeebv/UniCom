import 'package:flutter/material.dart';

/// A full-bleed brand photo used as a screen background.
///
/// Performance notes:
/// - Decodes at the on-screen pixel size via [cacheWidth]/[cacheHeight] so a
///   ~400 KB JPEG is not kept at full resolution in memory.
/// - Uses [FilterQuality.medium] (the 'high' setting re-runs a costly cubic
///   resample every frame and is a visible source of jank on scrolling forms).
/// - The decoded bytes are cached by the framework keyed on the resolved size,
///   so switching between auth screens re-uses the same texture.
class BrandPhoto extends StatelessWidget {
  const BrandPhoto({
    super.key,
    required this.assetPath,
    this.alignment = const Alignment(0, -0.15),
    this.fallbackColor = const Color(0xFF0C3A44),
  });

  final String assetPath;
  final Alignment alignment;
  final Color fallbackColor;

  /// A sensible decode target: most phones report a logical width ~= 400 and
  /// this caps the backing texture so scaled-up desktop windows do not force a
  /// gigantic decode.
  static const double _maxDecodeDimension = 1400;

  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.maybeDevicePixelRatioOf(context) ?? 1.0;
    final size = MediaQuery.maybeSizeOf(context) ?? const Size(400, 800);
    final decodeW = (size.width * dpr).clamp(1.0, _maxDecodeDimension).round();
    final decodeH = (size.height * dpr).clamp(1.0, _maxDecodeDimension).round();

    return Image.asset(
      assetPath,
      fit: BoxFit.cover,
      alignment: alignment,
      gaplessPlayback: true,
      filterQuality: FilterQuality.medium,
      cacheWidth: decodeW,
      cacheHeight: decodeH,
      errorBuilder:
          (_, _, _) => ColoredBox(color: fallbackColor),
    );
  }
}
