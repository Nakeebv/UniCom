import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:unicom/core/theme/theme.dart';
import 'package:unicom/data/demo/mock_backend.dart';
import 'package:unicom/features/chats/chats_screen.dart';
import 'package:unicom/features/contacts/friends_screen.dart';
import 'package:unicom/features/calls/calls_soon_screen.dart';
import 'package:unicom/features/settings/settings_screen.dart';
import 'package:unicom/features/shell/home_shell.dart';
import 'package:unicom/providers.dart';

/// Regression: the shell's nav items must line up with the router's branch
/// order (chats · calls · contacts · settings). Originally the Calls and
/// Contacts branches were swapped, so tapping an item lit the wrong tab.
void main() {
  testWidgets('bottom nav taps land on the matching branch', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final backend = MockBackend();
    await backend.load();
    await backend.signIn('nav@unicom.app');
    await backend.setLanguage('en');

    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final router = GoRouter(
      initialLocation: '/chats',
      routes: [
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
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [backendProvider.overrideWith((ref) => backend)],
        child: MaterialApp.router(theme: AppTheme.dark(), routerConfig: router),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));

    Future<void> tapTab(String label, Type screen) async {
      await tester.tap(find.text(label));
      await tester.pump(const Duration(milliseconds: 350));
      expect(
        find.byType(screen),
        findsOneWidget,
        reason: 'tapping "$label" must show the matching branch',
      );
    }

    await tapTab('Calls', CallsSoonScreen);
    await tapTab('Contacts', FriendsScreen);
    await tapTab('Settings', SettingsScreen);
    await tapTab('Messages', ChatsScreen);
  });
}
