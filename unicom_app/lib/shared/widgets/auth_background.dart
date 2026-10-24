import 'package:flutter/material.dart';

import 'brand_photo.dart';

/// Full-bleed photo background + brand scrims shared by the auth screens
/// (login / register / verify) so they blend with the welcome page.
///
/// This widget owns the *background only* — the [child] is responsible for its
/// own scrolling. The previous version nested a [SingleChildScrollView] around
/// a child [ListView], which produced unbounded-intrinsic layout work on every
/// keystroke and was the main cause of the sluggish auth screens.
class AuthBackground extends StatelessWidget {
  const AuthBackground({
    super.key,
    required this.child,
    this.imagePath = 'assets/onboarding/welcome_4.jpg',
    this.maxWidth = 460,
  });

  final Widget child;
  final String imagePath;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFF030A0B),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Full-bleed photo, edge to edge behind the status bar.
          Positioned.fill(child: BrandPhoto(assetPath: imagePath)),
          // Scrims: global tint + readability gradient over the form zone.
          const Positioned.fill(child: _AuthScrimSafe()),
          // Foreground form — the child scrolls itself.
          Positioned.fill(
            child: SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxWidth),
                  child: child,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Dark scrim so white form text stays readable over any photo.
class _AuthScrimSafe extends StatelessWidget {
  const _AuthScrimSafe();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            stops: const [0.0, 0.5, 1.0],
            colors: [
              const Color(0xFF030A0B).withValues(alpha: .45),
              const Color(0xFF030A0B).withValues(alpha: .68),
              const Color(0xFF030A0B).withValues(alpha: .82),
            ],
          ),
        ),
      ),
    );
  }
}
