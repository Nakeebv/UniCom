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
  // initializes. Without this, Android plays call audio to the earpiece/
  // receiver path and the speaker/mouthpiece never behave like a real call.
  try {
    // ignore: experimental_member_use
    await lk.LiveKitClient.initialize(
      // ignore: experimental_member_use
      initialAudioSessionOptions: const lk.AudioSessionOptions.communication(),
    );
  } catch (_) {
    // Desktop/web report this as unsupported — harmless.
  }

  // Hash URLs on web so the hosted build works from any subpath (QR/open).
  if (kIsWeb) {
    useHashUrls();
  }

  // Firebase Cloud Messaging: initialise before runApp so background/tap
  // handlers are registered early. No-op on web/desktop.
  await PushService.instance.init();

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
