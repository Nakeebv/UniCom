import 'package:flutter/material.dart';

/// Full-bleed photo background + brand scrims shared by the auth screens
/// (login / register / verify) so they blend with the welcome page.
///
/// Content is centered, capped at [maxWidth], and the surrounding scroll view
/// keeps it reachable when the viewport is too short (no clipping on small or
/// landscape screens).
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
    return Scaffold(
      backgroundColor: const Color(0xFF030A0B),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Full-bleed photo, edge to edge behind the status bar.
          Positioned.fill(
            child: Image.asset(
              imagePath,
              fit: BoxFit.cover,
              alignment: const Alignment(0, -0.15),
              filterQuality: FilterQuality.high,
              errorBuilder:
                  (_, _, _) => Container(color: const Color(0xFF0C3A44)),
            ),
          ),
          // Scrims: global tint + readability gradient over the form zone.
          const Positioned.fill(child: _AuthScrimSafe()),
          // Foreground form.
          Positioned.fill(
            child: SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 26,
                  vertical: 32,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: maxWidth),
                    child: child,
                  ),
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
              const Color(0xFF030A0B).withValues(alpha: .35),
              const Color(0xFF030A0B).withValues(alpha: .62),
              const Color(0xFF030A0B).withValues(alpha: .78),
            ],
          ),
        ),
      ),
    );
  }
}
