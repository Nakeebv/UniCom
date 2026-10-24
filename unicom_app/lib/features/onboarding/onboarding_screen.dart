import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/palette.dart';
import '../../shared/widgets/logo.dart';

/// Welcome page — full-bleed photo background, blended with brand-tuned
/// gradient scrims so text stays readable on every screen.
///
/// Responsive: content is centered within SafeArea, capped at 460px on wide
/// screens, and falls back to a scroll view when the viewport is too short.
class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final short = constraints.maxHeight < 700;

          final content = Center(
            child: SingleChildScrollView(
              physics:
                  short
                      ? const ClampingScrollPhysics()
                      : const NeverScrollableScrollPhysics(),
              padding: EdgeInsets.symmetric(
                horizontal: 28,
                vertical: short ? 24 : 40,
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const UniComLogo(size: 64),
                    const SizedBox(height: 10),
                    const Text(
                      'ONE WORLD. EVERY LANGUAGE.',
                      style: TextStyle(
                        color: Palette.teal03,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 2.4,
                      ),
                    ),
                    const SizedBox(height: 28),
                    const Text(
                      'Connect friends\nin every\nlanguage.',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 36,
                        height: 1.12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -.5,
                        shadows: [
                          Shadow(color: Colors.black54, blurRadius: 14),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'UniCom translates messages and voice notes into your '
                      'language — while the original always stays one tap away.',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: .92),
                        fontSize: 15,
                        height: 1.5,
                        shadows: const [
                          Shadow(color: Colors.black45, blurRadius: 10),
                        ],
                      ),
                    ),
                    SizedBox(height: short ? 24 : 40),
                    _GoogleButton(onTap: () => context.go('/auth/register')),
                    const SizedBox(height: 14),
                    Center(
                      child: Text(
                        'OR',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: .8),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 2.4,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: Palette.teal,
                          foregroundColor: const Color(0xFF06211F),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(28),
                          ),
                          textStyle: const TextStyle(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        onPressed: () => context.go('/auth/register'),
                        child: const Text('Sign up with Email'),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Center(
                      child: Text.rich(
                        TextSpan(
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: .85),
                            fontSize: 13.5,
                          ),
                          children: [
                            const TextSpan(text: 'Existing account? '),
                            WidgetSpan(
                              alignment: PlaceholderAlignment.middle,
                              child: GestureDetector(
                                onTap: () => context.go('/auth/login'),
                                child: const Text(
                                  'Log in',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13.5,
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );

          return Stack(
            fit: StackFit.expand,
            children: [
              // Full-bleed photo, edge to edge (behind status bar).
              Positioned.fill(
                child: Image.asset(
                  'assets/onboarding/welcome_2.jpg',
                  fit: BoxFit.cover,
                  alignment: const Alignment(0, -0.2),
                  filterQuality: FilterQuality.high,
                  errorBuilder:
                      (_, _, _) => Container(color: const Color(0xFF0C3A44)),
                ),
              ),
              // Blend scrims.
              const Positioned.fill(child: _WelcomeScrim()),
              // Foreground content.
              short ? SafeArea(child: content) : SafeArea(child: content),
            ],
          );
        },
      ),
    );
  }
}

/// Dual scrims: a global cool tint plus a bottom-weighted brand gradient so
/// the headline and every button stay readable on any photo.
class _WelcomeScrim extends StatelessWidget {
  const _WelcomeScrim();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Global unifying tint.
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  const Color(0xFF030A0B).withValues(alpha: .30),
                  const Color(0xFF030A0B).withValues(alpha: .42),
                ],
              ),
            ),
          ),
          // Bottom-weighted brand gradient for CTA readability.
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: const [0.0, 0.35, 0.55, 0.8, 1.0],
                colors: [
                  Colors.transparent,
                  Colors.transparent,
                  Palette.bg.withValues(alpha: .40),
                  Palette.bg.withValues(alpha: .82),
                  Palette.bg,
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// "Continue with Google" pill.
class _GoogleButton extends StatelessWidget {
  const _GoogleButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: OutlinedButton.icon(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          backgroundColor: Colors.white.withValues(alpha: .95),
          foregroundColor: const Color(0xFF101A1B),
          side: BorderSide.none,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(27),
          ),
        ),
        icon: const Icon(Icons.g_mobiledata_rounded, size: 30),
        label: const Text(
          'Continue with Google',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15.5),
        ),
      ),
    );
  }
}
