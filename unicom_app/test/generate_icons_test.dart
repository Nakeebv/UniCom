import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:unicom/core/theme/palette.dart';
import 'package:unicom/shared/widgets/logo.dart';

/// Generates brand icon assets from the vector logo.
/// Run: `flutter test test/generate_icons_test.dart --update-goldens`
/// then copy the produced goldens into assets/brand/unicorn/ if not already
/// redirected there directly below.
void main() {
  testWidgets('render app icon 1024', (tester) async {
    tester.view.physicalSize = const Size(1024, 1024);
    tester.view.devicePixelRatio = 1.0;

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(size: Size(1024, 1024)),
        child: RepaintBoundary(
          child: Container(
            width: 1024,
            height: 1024,
            color: const Color(0xFF0E1A1C),
            child: Center(
              child: SizedBox(
                width: 560,
                height: 560,
                child: CustomPaint(
                  painter: _IconBackdrop(),
                  child: const Center(
                    child: UniComLogo(size: 430, onSurface: LogoSurface.dark),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(RepaintBoundary),
      matchesGoldenFile('goldens/icon_1024.png'),
    );
  });

  testWidgets('render foreground (transparent bg) 1024', (tester) async {
    tester.view.physicalSize = const Size(1024, 1024);
    tester.view.devicePixelRatio = 1.0;

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(size: Size(1024, 1024)),
        child: RepaintBoundary(
          child: Container(
            width: 1024,
            height: 1024,
            color: Colors.transparent,
            child: Center(
              child: SizedBox(
                width: 620,
                height: 620,
                child: CustomPaint(
                  painter: _IconForeground(),
                  child: const Center(
                    child: UniComLogo(size: 420, onSurface: LogoSurface.dark),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(RepaintBoundary),
      matchesGoldenFile('goldens/icon_1024_foreground.png'),
    );
  });
}

/// Soft radial teal ambience behind the icon mark.
class _IconBackdrop extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final paint =
        Paint()
          ..shader = const RadialGradient(
            center: Alignment(0, -0.2),
            radius: 1.1,
            colors: [Color(0xFF12312E), Palette.darkHeader],
          ).createShader(rect);
    canvas.drawRect(rect, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Foreground keeps a transparent background with generous padding.
class _IconForeground extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {}

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
