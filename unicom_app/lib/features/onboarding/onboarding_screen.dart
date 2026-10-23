import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/palette.dart';
import '../../shared/widgets/logo.dart';

/// Welcome / onboarding — image-driven, premium, fully responsive.
///
/// A three-photo crossfade slideshow (bundled, preloaded) sits behind a
/// bottom-weighted scrim tuned so the headline, value proposition and CTAs
/// stay readable on every frame, every screen size, and both orientations.
///
/// The standalone "A" glyph decoration was removed at the source: the old
/// `_GlyphOrb('A')` ambience element no longer exists in this widget tree —
/// photo art has replaced the decorative orbs entirely.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  static const _slides = [
    'assets/onboarding/welcome_1.jpg', // portrait — strongest single subject
    'assets/onboarding/welcome_2.jpg', // leaning out of car — candid energy
    'assets/onboarding/welcome_3.jpg', // group laughing — social warmth
  ];

  static const _slideSeconds = Duration(seconds: 6);
  static const _fade = Duration(milliseconds: 1100);

  int _index = 0;
  late final _timer = Timer.periodic(_slideSeconds, (_) {
    if (mounted) {
      setState(() => _index = (_index + 1) % _slides.length);
    }
  });

  @override
  void initState() {
    super.initState();
    // Warm every frame after the first layout so the first crossfade never
    // flickers (context is only valid post-init).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      for (final path in _slides) {
        precacheImage(AssetImage(path), context);
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 600;
          final short = constraints.maxHeight < 780;
          final contentWidth =
              wide && constraints.maxHeight > 500 ? 460.0 : double.infinity;

          final content = _ContentColumn(
            width: contentWidth,
            constrained: wide,
          );

          return Stack(
            fit: StackFit.expand,
            children: [
              // ── Photo slideshow ────────────────────────────────────────
              AnimatedSwitcher(
                duration: _fade,
                switchInCurve: Curves.easeOut,
                switchOutCurve: Curves.easeIn,
                child: KeyedSubtree(
                  key: ValueKey(_index),
                  child: Image.asset(
                    _slides[_index],
                    fit: BoxFit.cover,
                    alignment: const Alignment(0, -0.15), // keep faces visible
                    gaplessPlayback: true,
                    filterQuality: FilterQuality.medium,
                  ),
                ),
              ),
              // ── Scrims: readability without hiding the photos ─────────
              const _Scrim(),
              // ── Foreground content ─────────────────────────────────────
              SafeArea(
                child:
                    short
                        ? SingleChildScrollView(
                          child: Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 460),
                              child: content,
                            ),
                          ),
                        )
                        : Align(
                          alignment: Alignment.bottomCenter,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 460),
                            child: content,
                          ),
                        ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Bottom-weighted scrim: near-solid brand base under the CTAs, fading to
/// almost nothing over the photo's face area, plus a faint cool tint across
/// the whole frame to unify the three photos' colour temperatures.
class _Scrim extends StatelessWidget {
  const _Scrim();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Global cool tint — subtle colour unification across the photos.
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  const Color(0xFF030A0B).withValues(alpha: .28),
                  const Color(0xFF030A0B).withValues(alpha: .38),
                ],
              ),
            ),
          ),
          // Bottom readability gradient.
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: const [0.0, 0.42, 0.62, 0.78, 1.0],
                colors: [
                  Colors.transparent,
                  Colors.transparent,
                  Palette.bg.withValues(alpha: .45),
                  Palette.bg.withValues(alpha: .86),
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

/// Foreground content: brand chip, headline, value line, Google CTA,
/// email sign-up pill and log-in link. Unchanged copy and actions.
class _ContentColumn extends StatelessWidget {
  const _ContentColumn({required this.width, required this.constrained});

  final double width;
  final bool constrained;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        28,
        constrained ? 60 : 0,
        28,
        constrained ? 48 : 26,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const UniComLogo(size: 52),
          const SizedBox(height: 10),
          Text(
            'ONE WORLD. EVERY LANGUAGE.',
            style: TextStyle(
              color: Palette.teal.withValues(alpha: .95),
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 2.2,
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'Connect friends\nin every\nlanguage.',
            style: TextStyle(
              color: Colors.white,
              fontSize: 34,
              height: 1.14,
              fontWeight: FontWeight.w800,
              letterSpacing: -.5,
              shadows: [Shadow(color: Colors.black45, blurRadius: 12)],
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'UniCom translates messages and voice notes into '
            'your language — while the original always stays '
            'one tap away.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: .88),
              fontSize: 14.5,
              height: 1.5,
              shadows: const [Shadow(color: Colors.black38, blurRadius: 10)],
            ),
          ),
          const SizedBox(height: 26),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: OutlinedButton.icon(
              onPressed: () => context.go('/auth/register'),
              style: OutlinedButton.styleFrom(
                backgroundColor: Colors.white.withValues(alpha: .94),
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
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              'OR',
              style: TextStyle(
                color: Colors.white.withValues(alpha: .75),
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 2.4,
              ),
            ),
          ),
          const SizedBox(height: 12),
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
          const SizedBox(height: 16),
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
    );
  }
}
