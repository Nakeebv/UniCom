import 'dart:async';
import 'dart:io' show Platform;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../data/api/unicom_api.dart';
import 'push_service.dart';

/// Background FCM handler — MUST be a top-level function.
/// Android delivers data messages here when the app is backgrounded/killed.
@pragma('vm:entry-point')
Future<void> _onBackgroundMessage(RemoteMessage message) async {
  // Firebase is already initialised by this point on Android. Nothing to do
  // here beyond logging; the OS shows the notification when the payload has a
  // `notification` block, and data-only messages are appended to a queue we
  // reconcile on resume.
  debugPrint('[unicom-notification] background message: ${message.messageId}');
}

// ignore_for_file: avoid_print

/// Mobile FCM implementation.
///
/// Central FCM integration for UniCom.
///
/// Responsibilities:
///  • initialise Firebase once (Android only for now),
///  • request notification permission,
///  • obtain + refresh the device token and register it with the backend
///    (authenticated; server stores it against the signed-in user),
///  • surface foreground messages as local notifications,
///  • create the high-importance Android channel used for calls,
///  • expose the call id of a notification the user tapped so the app can
///    deep-link into the call/conversation.
///
/// It NEVER holds credentials: the FCM service-account key lives only on the
/// backend, which is the only party that can send pushes.
class PushServiceImpl implements PushService {
  PushServiceImpl();

  static const String callChannelId = 'unicom_calls';
  static const String defaultChannelId = 'unicom_messages';

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();

  bool _initialised = false;
  String? _token;
  String? _pendingCallId;
  UniComApi? _api;

  /// The call id from the most recent tapped call notification (if any),
  /// consumed by the router once the user is authenticated.
  @override
  String? takePendingCallId() {
    final c = _pendingCallId;
    _pendingCallId = null;
    return c;
  }

  @override
  bool get isSupported => !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  /// Initialise once, before runApp. Safe to call on web (no-op).
  @override
  Future<void> init() async {
    if (_initialised || !isSupported) return;
    try {
      await Firebase.initializeApp();
      _initialised = true;
      debugPrint('[unicom-notification] firebase initialised');
    } catch (e) {
      debugPrint('[unicom-notification] firebase init failed: $e');
      return;
    }

    // Local notifications (foreground presentation + channels).
    const androidInit = AndroidInitializationSettings('@mipmap/launcher_icon');
    const iosInit = DarwinInitializationSettings();
    await _local.initialize(
      settings: const InitializationSettings(
        android: androidInit,
        iOS: iosInit,
      ),
      onDidReceiveNotificationResponse: (resp) {
        _handleTap(resp.payload);
      },
    );

    await _ensureAndroidChannels();
    await _requestPermission();

    FirebaseMessaging.onBackgroundMessage(_onBackgroundMessage);

    // Foreground messages → show a local notification so they are visible.
    FirebaseMessaging.onMessage.listen((m) {
      debugPrint(
        '[unicom-notification] foreground message type=${m.data['type']}',
      );
      _showForeground(m);
    });

    // Tap while app is backgrounded but alive.
    FirebaseMessaging.onMessageOpenedApp.listen((m) {
      debugPrint('[unicom-notification] opened from background: ${m.data}');
      _handleTapMap(m.data);
    });

    // Cold start from a notification (timeout-guarded: never hang).
    try {
      final initial = await _messaging.getInitialMessage().timeout(
        const Duration(seconds: 4),
        onTimeout: () => null,
      );
      if (initial != null) _handleTapMap(initial.data);
    } catch (_) {}

    _ensureAndroidChannelsToken();

    _messaging.onTokenRefresh.listen((t) {
      _token = t;
      debugPrint('[unicom-notification] token refreshed');
      unawaited(_registerToken());
    });
  }

  /// Fetch the token without blocking app start; logs the result safely.
  void _ensureAndroidChannelsToken() {
    _messaging
        .getToken()
        .timeout(const Duration(seconds: 6), onTimeout: () => null)
        .then((t) {
          _token = t;
          debugPrint('[unicom-notification] token obtained: ${_token != null}');
          unawaited(_registerToken());
        })
        .catchError((e) {
          debugPrint('[unicom-notification] getToken failed: $e');
          return null;
        });
  }

  /// Attach the authenticated API client and register the current token.
  /// Called after sign-in; also safe to call again once a session exists.
  @override
  Future<void> registerWithBackend(UniComApi api) async {
    _api = api;
    await _registerToken();
  }

  Future<void> _registerToken() async {
    final api = _api;
    final token = _token;
    if (api == null || token == null) return;
    try {
      await api.registerDeviceToken(
        token: token,
        platform: kIsWeb ? 'web' : (Platform.isIOS ? 'ios' : 'android'),
      );
      debugPrint('[unicom-notification] device token registered');
    } catch (e) {
      debugPrint('[unicom-notification] token register failed: $e');
    }
  }

  Future<void> _requestPermission() async {
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
    debugPrint(
      '[unicom-notification] permission=${settings.authorizationStatus.name}',
    );
    // Android 13+ POST_NOTIFICATIONS is also surfaced through the local
    // notifications plugin; requesting on the messaging plugin covers it.
  }

  Future<void> _ensureAndroidChannels() async {
    final android =
        _local
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();
    if (android == null) return;
    // High-importance channel for incoming calls (heads-up + sound).
    await android.createNotificationChannel(
      const AndroidNotificationChannel(
        callChannelId,
        'Incoming calls',
        description:
            'Ringing alerts for incoming UniCom voice and video calls.',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
      ),
    );
    await android.createNotificationChannel(
      const AndroidNotificationChannel(
        defaultChannelId,
        'Messages',
        description: 'New message notifications.',
        importance: Importance.high,
      ),
    );
  }

  void _showForeground(RemoteMessage m) {
    final data = m.data;
    final isCall = data['type'] == 'call';
    final title =
        m.notification?.title ?? (isCall ? 'Incoming call' : 'New message');
    final body = m.notification?.body ?? '';
    _local.show(
      id:
          m.messageId?.hashCode ??
          DateTime.now().millisecondsSinceEpoch.remainder(1 << 31),
      title: title,
      body: body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          isCall ? callChannelId : defaultChannelId,
          isCall ? 'Incoming calls' : 'Messages',
          importance: isCall ? Importance.max : Importance.high,
          priority: isCall ? Priority.max : Priority.high,
          category: isCall ? AndroidNotificationCategory.call : null,
          ongoing: isCall,
          autoCancel: !isCall,
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: data['call_id'] ?? data['conversation_id'],
    );
  }

  void _handleTap(String? payload) {
    if (payload != null) _pendingCallId = payload;
  }

  void _handleTapMap(Map<String, dynamic> data) {
    final id = data['call_id'] ?? data['conversation_id'];
    if (id is String) _pendingCallId = id;
  }
}

/// Factory used by the conditional import in push_service.dart.
PushService createPushService() => PushServiceImpl();
