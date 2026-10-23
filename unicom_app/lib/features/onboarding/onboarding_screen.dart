import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/palette.dart';
import '../../shared/widgets/logo.dart';

/// UniCom welcome: near-black canvas with a cyan glow, big display
/// headline, social sign-in row and a cyan pill CTA.
class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final double width = MediaQuery.sizeOf(context).width;
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0.85, -0.85),
            radius: 1.5,
            colors: [Color(0xFF0C3A44), Palette.welcome2],
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              // On narrow/short screens the decorative orbs shrink and hug the
              // edges so they never overlap the headline or overflow.
              final compact = constraints.maxWidth < 380;
              final orb = compact ? 40.0 : 56.0;
              return Stack(
                children: [
                  // Orbiting glyph ambience
                  Positioned(
                    top: compact ? 70 : 90,
                    right: compact ? 16 : 30,
                    child: _GlyphOrb('文', size: orb),
                  ),
                  Positioned(
                    top: compact ? 170 : 210,
                    left: compact ? 14 : 34,
                    child: _GlyphOrb('A', size: orb),
                  ),
                  Positioned(
                    bottom: compact ? 250 : 300,
                    right: compact ? 30 : 60,
                    child: Opacity(
                      opacity: .35,
                      child: _GlyphOrb('あ', small: true, size: orb),
                    ),
                  ),
                  Column(
                    children: [
                      const Spacer(flex: 4),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 30),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const UniComLogo(size: 54, animate: true),
                            const SizedBox(height: 8),
                            const Text(
                              'ONE WORLD. EVERY LANGUAGE.',
                              style: TextStyle(
                                color: Palette.teal03,
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 2.2,
                              ),
                            ),
                            const SizedBox(height: 26),
                            SizedBox(
                              width: width * .82,
                              child: const Text(
                                'Connect friends\nin every\nlanguage.',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 32,
                                  height: 1.18,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -.4,
                                ),
                              ),
                            ),
                            const SizedBox(height: 18),
                            Text(
                              'UniCom translates messages and voice notes into '
                              'your language — while the original always stays '
                              'one tap away.',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: .72),
                                fontSize: 14,
                                height: 1.55,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(flex: 5),
                      _GoogleButton(onTap: () => context.go('/auth/register')),
                      const SizedBox(height: 22),
                      Center(
                        child: Text(
                          'OR',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: .65),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 2.4,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: SizedBox(
                          width: double.infinity,
                          height: 58,
                          child: FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: Palette.cyan,
                              foregroundColor: const Color(0xFF00232B),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(29),
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
                      ),
                      const SizedBox(height: 22),
                      Center(
                        child: Text.rich(
                          TextSpan(
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: .7),
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
                      const SizedBox(height: 26),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _GlyphOrb extends StatelessWidget {
  const _GlyphOrb(this.glyph, {this.small = false, this.size});
  final String glyph;
  final bool small;
  final double? size;

  @override
  Widget build(BuildContext context) {
    final d = size ?? (small ? 40.0 : 56.0);
    return Container(
      width: d,
      height: d,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .08),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white24),
      ),
      child: Center(
        child: Text(
          glyph,
          style: TextStyle(
            color: Colors.white.withValues(alpha: .8),
            fontSize: d * .4,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _GoogleButton extends StatelessWidget {
  const _GoogleButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: SizedBox(
        width: double.infinity,
        height: 56,
        child: OutlinedButton.icon(
          onPressed: onTap,
          style: OutlinedButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: const Color(0xFF101A1B),
            side: BorderSide.none,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(28),
            ),
          ),
          icon: const Icon(Icons.g_mobiledata_rounded, size: 30),
          label: const Text(
            'Continue with Google',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15.5),
          ),
        ),
      ),
    );
  }
}
