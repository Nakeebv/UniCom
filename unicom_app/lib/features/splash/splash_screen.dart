import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers.dart';
import '../../shared/widgets/logo.dart';

/// UniCom splash: near-black canvas, centered cyan-gradient wordmark.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _precacheBrandImagery();
    _waitReady();
  }

  /// Warm the auth/welcome background photos while the splash is visible so
  /// the first navigation into onboarding/login renders instantly instead of
  /// decoding a multi-hundred-KB JPEG on the critical path.
  void _precacheBrandImagery() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      for (final path in const [
        'assets/onboarding/welcome_2.jpg',
        'assets/onboarding/welcome_4.jpg',
        'assets/brand/logo_full.png',
      ]) {
        precacheImage(AssetImage(path), context);
      }
    });
  }

  Future<void> _waitReady() async {
    final backend = ref.read(backendProvider);
    final limit = DateTime.now().add(const Duration(seconds: 6));
    while (!backend.ready && DateTime.now().isBefore(limit)) {
      await Future<void>.delayed(const Duration(milliseconds: 120));
      ref.read(backendProvider);
    }
    if (!mounted) return;

    Future<void>.delayed(const Duration(milliseconds: 250), () {
      if (!mounted) return;
      final backend = ref.read(backendProvider);
      if (!backend.isSignedIn) {
        context.go('/onboarding');
      } else if (!backend.onboarded) {
        context.go('/auth/language');
      } else {
        backend.ensureSeeded();
        context.go('/chats');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF030A0B),
      body: Center(
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 800),
          curve: Curves.easeOutCubic,
          builder:
              (context, t, _) => Transform.scale(
                scale: .9 + .1 * t,
                child: Opacity(
                  opacity: t.clamp(0, 1),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const UniComLogo(size: 108, animate: true),
                      const SizedBox(height: 20),
                      ShaderMask(
                        shaderCallback:
                            (bounds) => const LinearGradient(
                              colors: [Color(0xFF32D8F2), Color(0xFF0BBEDC)],
                            ).createShader(bounds),
                        child: const Text(
                          'UniCom',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 30,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.1,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
        ),
      ),
    );
  }
}
