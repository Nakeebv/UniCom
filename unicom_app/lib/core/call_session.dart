import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:livekit_client/livekit_client.dart' as lk;
import 'package:permission_handler/permission_handler.dart';

import '../data/api/unicom_api.dart';

/// Lifecycle of a 1:1 call as the UI cares about it. Media connectivity is
/// only reported "connected" after the LiveKit engine confirms it.
enum CallPhase { connecting, connected, reconnecting, ended, failed }

/// Wraps LiveKit for one 1:1 room: connect with a server-minted token,
/// publish mic (+camera for video), expose participants/tracks, and release
/// everything on hang-up.
///
/// All LiveKit signal/media failures surface as [CallPhase.failed] with the
/// real reason (e.g. LiveKit rejecting invalid credentials) — never silently.
class CallSession extends ChangeNotifier {
  CallSession({
    required this.api,
    required this.room,
    required this.isVideo,
    this.callId,
  });

  final UniComApi api;
  final String room;
  final String? callId;
  final bool isVideo;

  lk.Room? _liveRoom;
  CallPhase _phase = CallPhase.connecting;
  String? _error;
  bool _micEnabled = true;
  bool _camEnabled = true;
  bool _camDenied = false;
  DateTime? _connectedAt;
  Timer? _durationTimer;
  Duration _duration = Duration.zero;
  bool _frontCamera = true;
  void Function()? _cancelEvents;

  CallPhase get phase => _phase;
  String? get error => _error;
  bool get micEnabled => _micEnabled;
  bool get camEnabled => _camEnabled;
  bool get camDenied => _camDenied;
  Duration get duration => _duration;
  lk.Room? get liveRoom => _liveRoom;

  /// Connected = LiveKit signaling AND media pipeline confirmed.
  bool get mediaConnected =>
      _phase == CallPhase.connected &&
      _liveRoom?.connectionState == lk.ConnectionState.connected;

  /// The other participant's video/audio tracks (empty until they publish).
  lk.Participant? get remoteParticipant {
    final r = _liveRoom;
    if (r == null) return null;
    for (final p in r.remoteParticipants.values) {
      return p;
    }
    return null;
  }

  lk.Participant? get localParticipant => _liveRoom?.localParticipant;

  /// Diagnostics — safe to log: no tokens, no secrets. [redact] strips the
  /// wss host name for log hygiene.
  void log(String message) {
    // ignore: avoid_print
    print('[unicom-call][$room/$identityTag] $message');
  }

  String get identityTag => isVideo ? 'video' : 'audio';

  /// Connects to the room. [peerId] is the other user; the token is minted
  /// server-side with call-participant authorization.
  Future<void> connect({required String peerId}) async {
    _phase = CallPhase.connecting;
    notifyListeners();
    log('connect begin (peer: $peerId)');
    try {
      final grant = await api
          .callToken(callId: callId!)
          .timeout(
            const Duration(seconds: 15),
            onTimeout: () {
              throw StateError('token request timed out');
            },
          );
      if (grant == null) {
        _phase = CallPhase.failed;
        _error = 'Calling is not configured on this server yet.';
        log(_error!);
        notifyListeners();
        return;
      }
      final url = grant['url'] as String;
      final token = grant['token'] as String;
      log('token acquired (room: $room, ${token.length}b payload)');

      final liveRoom = lk.Room(
        roomOptions: const lk.RoomOptions(adaptiveStream: true, dynacast: true),
      );
      _liveRoom = liveRoom;

      liveRoom.addListener(_onRoomChanged);
      _cancelEvents = liveRoom.events.listen(_onRoomEvent);
      log('connecting to LiveKit server…');

      await liveRoom
          .connect(url, token)
          .timeout(
            const Duration(seconds: 20),
            onTimeout: () {
              throw StateError(
                'LiveKit connection timed out — server unreachable or credentials rejected',
              );
            },
          );
      log('signaling connected (state: ${liveRoom.connectionState})');

      // Publish local media per call type. Mic permission first: without it
      // some Android ROMs silently produce an empty track.
      final mic = await Permission.microphone.request();
      if (!mic.isGranted) {
        throw StateError('Microphone permission was not granted');
      }
      await liveRoom.localParticipant?.setMicrophoneEnabled(true);
      log('microphone published');

      if (isVideo) {
        try {
          final cam = await Permission.camera.request();
          _camDenied = !(cam.isGranted || cam.isLimited);
          if (!_camDenied) {
            await liveRoom.localParticipant?.setCameraEnabled(true);
            log('camera published');
          } else {
            log('camera denied → continuing audio-only');
          }
        } catch (e) {
          _camDenied = true;
          log('camera failed → audio-only (${e.toString().split('\n').first})');
        }
      }

      // Room joined but peer hasn't connected yet → still "connecting."
      // The timer starts ONLY when the remote peer actually joins, so both
      // devices count from the same moment.
      if ((liveRoom.remoteParticipants.isEmpty)) {
        log('waiting for peer to join room…');
        return;
      }
      _phase = CallPhase.connected;
      _connectedAt = DateTime.now();
      _startDuration();
      notifyListeners();
    } catch (e) {
      _phase = CallPhase.failed;
      _error = _friendly(e.toString());
      log('connect FAILED: $_error');
      await _release();
      notifyListeners();
    }
  }

  /// Maps raw engine errors to user-facing words without exposing internals.
  String _friendly(String raw) {
    final l = raw.toLowerCase();
    if (l.contains('invalid') &&
        (l.contains('token') || l.contains('api key'))) {
      return 'LiveKit rejected the call credentials. Check LIVEKIT_API_KEY '
          'and LIVEKIT_API_SECRET on the server.';
    }
    if (l.contains('timeout') || l.contains('unreachable')) {
      return 'Could not reach the call server. Check the network and the '
          'LIVEKIT_URL configuration.';
    }
    if (l.contains('permission')) return raw;
    return raw.length > 180 ? '${raw.substring(0, 180)}…' : raw;
  }

  /// Structured LiveKit event diagnostics + track bookkeeping.
  void _onRoomEvent(lk.RoomEvent event) {
    if (event is lk.RoomDisconnectedEvent) {
      log('room disconnected (reason: ${event.reason})');
      if (_phase != CallPhase.ended) {
        _phase = CallPhase.failed;
        _error = 'Call disconnected (${event.reason?.name ?? 'network'})';
        notifyListeners();
      }
      return;
    }
    String pidOf(Object e) {
      try {
        return (e as dynamic).participant.identity as String;
      } catch (_) {
        return '?';
      }
    }

    final p = pidOf(event);
    if (event is lk.ParticipantConnectedEvent) {
      log('peer connected: ${_safeId(p)}');
      if (_phase == CallPhase.connecting) {
        _phase = CallPhase.connected;
        _connectedAt = DateTime.now();
        _startDuration();
        log('call ACTIVE — peer arrived, timer started');
      }
      notifyListeners();
    } else if (event is lk.ParticipantDisconnectedEvent) {
      log('peer disconnected: ${_safeId(p)}');
    } else if (event is lk.TrackSubscribedEvent) {
      log('remote ${event.track.kind} subscribed: ${_safeId(p)}');
    } else if (event is lk.TrackUnsubscribedEvent) {
      log('remote ${event.track.kind} unsubscribed: ${_safeId(p)}');
    } else if (event is lk.TrackMutedEvent || event is lk.TrackUnmutedEvent) {
      log('remote track mute change: ${_safeId(p)}');
    }
    notifyListeners();
  }

  /// Never print raw identities to logs; only a stable short tag.
  String _safeId(String identity) =>
      identity.length <= 8 ? identity : '${identity.substring(0, 8)}…';

  void _onRoomChanged() {
    final r = _liveRoom;
    if (r == null) return;
    if (r.connectionState == lk.ConnectionState.reconnecting &&
        _phase == CallPhase.connected) {
      _phase = CallPhase.reconnecting;
      log('reconnecting…');
      notifyListeners();
    } else if (r.connectionState == lk.ConnectionState.connected &&
        _phase == CallPhase.reconnecting) {
      _phase = CallPhase.connected;
      log('reconnected');
      notifyListeners();
    } else {
      notifyListeners();
    }
  }

  void _startDuration() {
    _durationTimer?.cancel();
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_connectedAt != null) {
        _duration = DateTime.now().difference(_connectedAt!);
        notifyListeners();
      }
    });
  }

  Future<void> toggleMic() async {
    _micEnabled = !_micEnabled;
    await _liveRoom?.localParticipant?.setMicrophoneEnabled(_micEnabled);
    log('mic ${_micEnabled ? 'on' : 'off'}');
    notifyListeners();
  }

  Future<void> toggleCamera() async {
    if (!isVideo || _camDenied) return;
    _camEnabled = !_camEnabled;
    await _liveRoom?.localParticipant?.setCameraEnabled(_camEnabled);
    log('camera ${_camEnabled ? 'on' : 'off'}');
    notifyListeners();
  }

  Future<void> switchCamera() async {
    try {
      final tracks =
          _liveRoom?.localParticipant?.videoTrackPublications ?? const [];
      if (tracks.isEmpty) return;
      final track = tracks.first.track;
      if (track is! lk.LocalVideoTrack) return;
      _frontCamera = !_frontCamera;
      await track.setCameraPosition(
        _frontCamera ? lk.CameraPosition.front : lk.CameraPosition.back,
      );
    } catch (_) {
      /* camera switching unsupported on this platform */
    }
  }

  Future<void> hangUp() async {
    log('hang up');
    _phase = CallPhase.ended;
    _durationTimer?.cancel();
    notifyListeners();
    await _liveRoom?.disconnect();
    await _release();
  }

  Future<void> _release() async {
    _cancelEvents?.call();
    _liveRoom?.removeListener(_onRoomChanged);
    await _liveRoom?.dispose();
    _liveRoom = null;
  }

  @override
  void dispose() {
    _durationTimer?.cancel();
    _cancelEvents?.call();
    _release();
    super.dispose();
  }
}
