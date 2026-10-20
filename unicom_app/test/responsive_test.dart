import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:unicom/core/theme/theme.dart';
import 'package:unicom/data/demo/mock_backend.dart';
import 'package:unicom/features/chat/chat_screen.dart';
import 'package:unicom/features/chats/chats_screen.dart';
import 'package:unicom/features/contacts/friends_screen.dart';
import 'package:unicom/features/settings/settings_screen.dart';
import 'package:unicom/providers.dart';

/// Responsive test matrix (logical pixels) from the brief.
const _viewports = <String, Size>{
  'compact 320x568': Size(320, 568),
  'small 360x640': Size(360, 640),
  'standard 390x844': Size(390, 844),
  'large 430x932': Size(430, 932),
  'landscape 640x360': Size(640, 360),
  'tablet 768x1024': Size(768, 1024),
  'large tablet 1024x1366': Size(1024, 1366),
  'wide 1440x900': Size(1440, 900),
};

Future<MockBackend> _bootBackend() async {
  SharedPreferences.setMockInitialValues({});
  final backend = MockBackend();
  await backend.load();
  await backend.signIn('demo@unicom.app');
  await backend.setLanguage('en');
  backend.ensureSeeded();
  return backend;
}

Future<void> _pumpScreen(
  WidgetTester tester,
  Widget screen,
  Size size,
  MockBackend backend,
) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [backendProvider.overrideWith((ref) => backend)],
      child: MaterialApp(theme: AppTheme.dark(), home: screen),
    ),
  );
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  for (final entry in _viewports.entries) {
    final name = entry.key;
    final size = entry.value;

    testWidgets('Chats screen — no overflow @ $name', (tester) async {
      final backend = await _bootBackend();
      await _pumpScreen(tester, const ChatsScreen(), size, backend);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Contacts screen — no overflow @ $name', (tester) async {
      final backend = await _bootBackend();
      await _pumpScreen(tester, const FriendsScreen(), size, backend);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Settings screen — no overflow @ $name', (tester) async {
      final backend = await _bootBackend();
      await _pumpScreen(tester, const SettingsScreen(), size, backend);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Chat screen — no overflow @ $name', (tester) async {
      final backend = await _bootBackend();
      final convId = backend.conversations.first.id;
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final router = GoRouter(
        initialLocation: '/chat/$convId',
        routes: [
          GoRoute(path: '/chat/:id', builder: (c, s) => const ChatScreen()),
        ],
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [backendProvider.overrideWith((ref) => backend)],
          child: MaterialApp.router(
            theme: AppTheme.dark(),
            routerConfig: router,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));
      // Drain the demo backend's simulated timers (delivery receipts,
      // translation, voice note). Nested Future.delayed chains need several
      // pump cycles to fully drain before disposal.
      for (var i = 0; i < 12; i++) {
        await tester.pump(const Duration(seconds: 1));
      }
      final err = tester.takeException();
      if (err != null) {
        final msg = err.toString();
        expect(
          msg.contains('overflowed') || msg.contains('RenderFlex'),
          isFalse,
          reason: 'Layout overflow on chat screen: $msg',
        );
      }
      // Dispose the tree so remaining demo timers don't leak between tests.
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  // Text-scaling: extra-large accessibility font must not overflow.
  for (final scale in [1.0, 1.5, 2.0]) {
    testWidgets('Chats screen — no overflow @ textScale ${scale}x', (
      tester,
    ) async {
      final backend = await _bootBackend();
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [backendProvider.overrideWith((ref) => backend)],
          child: MaterialApp(theme: AppTheme.dark(), home: const ChatsScreen()),
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));
      expect(tester.takeException(), isNull);
    });
  }
}
