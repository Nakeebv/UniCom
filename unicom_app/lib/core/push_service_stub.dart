import '../data/api/unicom_api.dart';
import 'push_service.dart';

/// Web / unsupported platforms: a no-op push service.
///
/// Kept free of any Firebase import so the web bundle never pulls in the
/// Firebase JS SDK (which previously broke the web boot).
class PushServiceStub implements PushService {
  @override
  bool get isSupported => false;

  @override
  Future<void> init() async {}

  @override
  Future<void> registerWithBackend(UniComApi api) async {}

  @override
  String? takePendingCallId() => null;
}

PushService createPushService() => PushServiceStub();
