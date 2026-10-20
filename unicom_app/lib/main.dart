import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(statusBarColor: Colors.transparent),
  );

  final container = ProviderContainer();
  // Warm the demo backend (restores persisted profile + settings).
  await container.read(backendProvider).load();

  runApp(
    UncontrolledProviderScope(container: container, child: const UniComApp()),
  );
}
