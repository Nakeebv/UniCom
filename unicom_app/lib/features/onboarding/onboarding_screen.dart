import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/palette.dart';
import '../../shared/widgets/logo.dart';

/// UniCom welcome — restored gradient edition.
///
/// Near-black canvas with a cyan glow, the brand emblem, large display
/// headline, "Continue with Google", the email sign-up pill and a log-in
/// link. The decorative glyph orbs from the original were removed (the
/// standalone "A" in particular) and the column now falls back to a scroll
/// view on short/landscape screens so nothing is ever clipped.
class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
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
              // The stacked CTA column needs ~720px; below that we scroll so
              // buttons can never clip on small or landscape screens.
              final needsScroll = constraints.maxHeight < 760;

              final content = Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 460),
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      28,
                      needsScroll ? 32 : 0,
                      28,
                      needsScroll ? 32 : 0,
                    ),
                    child: Column(
                      mainAxisSize:
                          needsScroll ? MainAxisSize.min : MainAxisSize.max,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (!needsScroll) const Spacer(flex: 4),
                        Column(
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
                            const Text(
                              'Connect friends\nin every\nlanguage.',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 32,
                                height: 1.18,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -.4,
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
                        if (!needsScroll) const Spacer(flex: 5),
                        if (needsScroll) const SizedBox(height: 34),
                        _GoogleButton(
                          onTap: () => context.go('/auth/register'),
                        ),
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
                        SizedBox(
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
                        const SizedBox(height: 12),
                      ],
                    ),
                  ),
                ),
              );

              return needsScroll
                  ? SingleChildScrollView(child: content)
                  : content;
            },
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
    return SizedBox(
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
    );
  }
}
