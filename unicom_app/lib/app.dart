import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/call_ring_controller.dart';
import 'core/theme/theme.dart';
import 'features/auth/language_setup_screen.dart';
import 'features/auth/login_screen.dart';
import 'features/auth/register_screen.dart';
import 'features/auth/verify_screen.dart';
import 'features/calls/calls_soon_screen.dart';
import 'features/calls/incoming_call_screen.dart';
import 'features/calls/live_call_screen.dart';
import 'features/chat/chat_screen.dart';
import 'features/chats/chats_screen.dart';
import 'features/contacts/friends_screen.dart';
import 'features/groups/group_create_screen.dart';
import 'features/groups/poll_create_screen.dart';
import 'features/onboarding/onboarding_screen.dart';
import 'features/profile/profile_view_screen.dart';
import 'features/settings/language_screen.dart';
import 'features/settings/privacy_screen.dart';
import 'features/settings/profile_screen.dart';
import 'features/settings/settings_screen.dart';
import 'features/settings/voice_screen.dart';
import 'features/shell/home_shell.dart';
import 'features/splash/splash_screen.dart';
import 'providers.dart';

class UniComApp extends ConsumerStatefulWidget {
  const UniComApp({super.key});

  @override
  ConsumerState<UniComApp> createState() => _UniComAppState();
}

class _UniComAppState extends ConsumerState<UniComApp> {
  late final GoRouter _router = _createRouter();

  GoRouter _createRouter() {
    return GoRouter(
      initialLocation: '/',
      redirect: (context, state) {
        // Read live session state on every navigation attempt — a signup or
        // sign-in performed inside the app immediately unblocks protected
        // routes.
        final backend = ref.read(backendProvider);
        final signedIn = backend.isSignedIn;
        final onboarded = backend.onboarded;

        final path = state.matchedLocation;
        final inAuth = path.startsWith('/auth') || path == '/onboarding';
        if (path == '/' || path == '/splash') return null; // splash decides
        if (signedIn && !onboarded && path != '/auth/language') {
          return '/auth/language';
        }
        if (!signedIn && !inAuth) return '/onboarding';
        return null;
      },
      routes: [
        GoRoute(path: '/', builder: (c, s) => const SplashScreen()),
        GoRoute(path: '/splash', builder: (c, s) => const SplashScreen()),
        GoRoute(
          path: '/onboarding',
          builder: (c, s) => const OnboardingScreen(),
        ),
        GoRoute(
          path: '/auth/register',
          builder: (c, s) => const RegisterScreen(),
        ),
        GoRoute(path: '/auth/login', builder: (c, s) => const LoginScreen()),
        GoRoute(path: '/auth/verify', builder: (c, s) => const VerifyScreen()),
        GoRoute(
          path: '/auth/language',
          builder: (c, s) => const LanguageSetupScreen(),
        ),
        // Protected shell
        StatefulShellRoute.indexedStack(
          builder:
              (context, state, shell) =>
                  HomeShell(index: shell.currentIndex, child: shell),
          branches: [
            StatefulShellBranch(
              routes: [
                GoRoute(path: '/chats', builder: (c, s) => const ChatsScreen()),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/calls',
                  builder: (c, s) => const CallsSoonScreen(),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/contacts',
                  builder: (c, s) => const FriendsScreen(),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/settings',
                  builder: (c, s) => const SettingsScreen(),
                ),
              ],
            ),
          ],
        ),
        GoRoute(path: '/chat/:id', builder: (c, s) => const ChatScreen()),
        GoRoute(
          path: '/profile/view/:id',
          builder: (c, s) => const ProfileViewScreen(),
        ),
        GoRoute(
          path: '/group/new',
          builder: (c, s) => const GroupCreateScreen(),
        ),
        GoRoute(
          path: '/poll/new/:id',
          builder: (c, s) => const PollCreateScreen(),
        ),
        GoRoute(
          path: '/call/incoming/:id',
          builder: (c, s) => const IncomingCallScreen(),
        ),
        GoRoute(
          path: '/call/live/:id',
          builder: (c, s) => const LiveCallScreen(),
        ),
        GoRoute(
          path: '/settings/profile',
          builder: (c, s) => const ProfileScreen(),
        ),
        GoRoute(
          path: '/settings/language',
          builder: (c, s) => const LanguageScreen(),
        ),
        GoRoute(
          path: '/settings/voice',
          builder: (c, s) => const VoiceScreen(),
        ),
        GoRoute(
          path: '/settings/privacy',
          builder: (c, s) => const PrivacyScreen(),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);
    return MaterialApp.router(
      title: 'UniCom',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      routerConfig: _router,
      builder:
          (context, child) =>
              _CallRinger(child: child ?? const SizedBox.shrink()),
    );
  }
}

/// Global incoming-call overlay: watches the backend's ringing state and
/// surfaces the incoming-call screen over whatever the user is doing.
class _CallRinger extends ConsumerStatefulWidget {
  const _CallRinger({required this.child});
  final Widget child;

  @override
  ConsumerState<_CallRinger> createState() => _CallRingerState();
}

class _CallRingerState extends ConsumerState<_CallRinger> {
  final CallRingController _ringer = CallRingController();
  bool _wasRinging = false;

  @override
  void dispose() {
    _ringer.stopRinging();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(backendProvider, (_, next) {
      final call = next.isSignedIn ? next.incomingCall : null;
      if (call != null && !_wasRinging) {
        _ringer.startRinging();
        _wasRinging = true;
      } else if (call == null && _wasRinging) {
        _ringer.stopRinging();
        _wasRinging = false;
      }
    });

    final backend = ref.watch(backendProvider);
    final call = backend.isSignedIn ? backend.incomingCall : null;
    return Stack(
      children: [
        widget.child,
        if (call != null)
          Positioned.fill(
            child: IncomingCallOverlay(
              callerId: call['caller_id'] as String? ?? '',
              callId: call['call_id'] as String? ?? '',
              callType: call['call_type'] as String? ?? 'audio',
            ),
          ),
      ],
    );
  }
}
