import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'data/demo/mock_backend.dart';
import 'data/models/conversation.dart';

/// Single demo-backend instance for the whole app.
final backendProvider = ChangeNotifierProvider<MockBackend>(
  (ref) => MockBackend(),
);

/// Convenience selectors (still fine to watch the backend directly).
final conversationsProvider = Provider<List<Conversation>>((ref) {
  final backend = ref.watch(backendProvider);
  return backend.conversations;
});

final themeModeProvider = Provider<ThemeMode>((ref) {
  return ref.watch(backendProvider).themeMode;
});

final myProfileProvider = Provider((ref) => ref.watch(backendProvider).me);
