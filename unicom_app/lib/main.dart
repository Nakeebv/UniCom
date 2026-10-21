import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flutter/foundation.dart' show kIsWeb;

import 'app.dart';
import 'util/web_strategy.dart';
import 'providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(statusBarColor: Colors.transparent),
  );

  // Hash URLs on web so the hosted build works from any subpath (QR/open).
  if (kIsWeb) {
    useHashUrls();
  }

  final container = ProviderContainer();
  // Warm the demo backend (restores persisted profile + settings).
  await container.read(backendProvider).load();

  runApp(
    UncontrolledProviderScope(container: container, child: const UniComApp()),
  );
}
