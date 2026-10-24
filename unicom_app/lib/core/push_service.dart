import '../data/api/unicom_api.dart';

// Resolves to the stub on web, the real implementation on mobile/desktop.
import 'push_service_stub.dart'
    if (dart.library.io) 'push_service_io.dart'
    as impl;

/// Platform-agnostic push service contract.
///
/// The concrete implementation is chosen by conditional import:
///  • IO (Android/iOS): `push_service_io.dart` — real Firebase Cloud Messaging.
///  • Web: `push_service_stub.dart` — a safe no-op (Firebase Messaging has no
///    working web path in this app yet, and importing it must not break the
///    web bundle).
abstract class PushService {
  /// Singleton the app talks to.
  static PushService get instance => _impl;

  /// True only where a real push stack exists.
  bool get isSupported;

  /// Initialise once before runApp. No-op where unsupported.
  Future<void> init();

  /// Register the current device token against the signed-in user.
  Future<void> registerWithBackend(UniComApi api);

  /// Consume a call/conversation id captured from a tapped notification.
  String? takePendingCallId();
}

final PushService _impl = impl.createPushService();
