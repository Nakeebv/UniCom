import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:livekit_client/livekit_client.dart' as lk;

import '../data/api/unicom_api.dart';

/// Lifecycle of a 1:1 call as the UI cares about it. Media connectivity is
/// only reported "connected" after the LiveKit engine confirms it.
enum CallPhase { connecting, connected, reconnecting, ended, failed }

/// Wraps LiveKit for one 1:1 room: connect with a server-minted token,
/// publish mic (+camera for video), expose participants/tracks, and release
/// everything on hang-up.
class CallSession extends ChangeNotifier {
  CallSession({required this.api, required this.room, required this.isVideo});

  final UniComApi api;
  final String room;
  final bool isVideo;

  lk.Room? _liveRoom;
  CallPhase _phase = CallPhase.connecting;
  String? _error;
  bool _micEnabled = true;
  bool _camEnabled = true;
  DateTime? _connectedAt;
  Timer? _durationTimer;
  Duration _duration = Duration.zero;
  bool _frontCamera = true;

  CallPhase get phase => _phase;
  String? get error => _error;
  bool get micEnabled => _micEnabled;
  bool get camEnabled => _camEnabled;
  Duration get duration => _duration;
  lk.Room? get liveRoom => _liveRoom;

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

  /// Connects to the room. [peerId] is the other user; the token is minted
  /// server-side with block + membership authorization.
  Future<void> connect({required String peerId}) async {
    _phase = CallPhase.connecting;
    notifyListeners();
    try {
      final grant = await api.callToken(
        peerId: peerId,
        room: room,
        callType: isVideo ? 'video' : 'audio',
      );
      if (grant == null) {
        _phase = CallPhase.failed;
        _error = 'Calling is not configured on this server yet.';
        notifyListeners();
        return;
      }
      final url = grant['url'] as String;
      final token = grant['token'] as String;

      final liveRoom = lk.Room(
        roomOptions: const lk.RoomOptions(adaptiveStream: true, dynacast: true),
      );
      _liveRoom = liveRoom;

      liveRoom.addListener(_onRoomChanged);
      await liveRoom.connect(url, token);
      // Publish local media per call type.
      await liveRoom.localParticipant?.setMicrophoneEnabled(true);
      if (isVideo) {
        await liveRoom.localParticipant?.setCameraEnabled(true);
      }
      _phase = CallPhase.connected;
      _connectedAt = DateTime.now();
      _startDuration();
      notifyListeners();
    } catch (e) {
      _phase = CallPhase.failed;
      _error = e.toString();
      notifyListeners();
    }
  }

  void _onRoomChanged() {
    final r = _liveRoom;
    if (r == null) return;
    if (r.connectionState == lk.ConnectionState.reconnecting &&
        _phase == CallPhase.connected) {
      _phase = CallPhase.reconnecting;
      notifyListeners();
    } else if (r.connectionState == lk.ConnectionState.connected &&
        _phase == CallPhase.reconnecting) {
      _phase = CallPhase.connected;
      notifyListeners();
    } else {
      // Track/participant updates: rebuild so video tiles appear.
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
    notifyListeners();
  }

  Future<void> toggleCamera() async {
    if (!isVideo) return;
    _camEnabled = !_camEnabled;
    await _liveRoom?.localParticipant?.setCameraEnabled(_camEnabled);
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
    _phase = CallPhase.ended;
    _durationTimer?.cancel();
    notifyListeners();
    await _liveRoom?.disconnect();
    await _release();
  }

  Future<void> _release() async {
    _liveRoom?.removeListener(_onRoomChanged);
    await _liveRoom?.dispose();
    _liveRoom = null;
  }

  @override
  void dispose() {
    _durationTimer?.cancel();
    _release();
    super.dispose();
  }
}
