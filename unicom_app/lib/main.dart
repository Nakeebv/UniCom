import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:livekit_client/livekit_client.dart' as lk;

import 'package:flutter/foundation.dart' show kIsWeb;

import 'app.dart';
import 'core/push_service.dart';
import 'util/web_strategy.dart';
import 'providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(statusBarColor: Colors.transparent),
  );

  // Configure the native audio session for two-way voice BEFORE WebRTC
  // initializes. Never block first paint on it — a device that stalls here
  // must still render the UI.
  unawaited(
    lk.LiveKitClient.initialize(
      // ignore: experimental_member_use
      initialAudioSessionOptions: const lk.AudioSessionOptions.communication(),
    ).timeout(const Duration(seconds: 5), onTimeout: () {}),
  );

  // Hash URLs on web so the hosted build works from any subpath (QR/open).
  if (kIsWeb) {
    useHashUrls();
  }

  // Firebase Cloud Messaging: initialise in the BACKGROUND. If it hangs (no
  // Play Services / misconfig) it must not block runApp — that caused a
  // permanent white screen.
  unawaited(
    PushService.instance.init().timeout(
      const Duration(seconds: 6),
      onTimeout: () {},
    ),
  );

  final container = ProviderContainer();
  // Warm the backend without blocking first paint (WhatsApp-like cold
  // start): splash navigates once [UniBackend.onboarded]/routes settle.
  unawaited(
    container
        .read(backendProvider)
        .load()
        .timeout(const Duration(seconds: 6), onTimeout: () {}),
  );

  runApp(
    UncontrolledProviderScope(container: container, child: const UniComApp()),
  );
}
