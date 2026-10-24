import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:livekit_client/livekit_client.dart' as lk;

import '../../core/call_session.dart';
import '../../core/theme/palette.dart';
import '../../data/api/remote_backend.dart';
import '../../providers.dart';
import '../../shared/widgets/ui_kit.dart';

/// Live 1:1 call — connects to a real LiveKit room using a server-minted,
/// room-scoped token. Shows connecting → connected (with real remote video)
/// → reconnecting / ended / failed. Every control performs its real action.
class LiveCallScreen extends ConsumerStatefulWidget {
  const LiveCallScreen({super.key});

  @override
  ConsumerState<LiveCallScreen> createState() => _LiveCallScreenState();
}

class _LiveCallScreenState extends ConsumerState<LiveCallScreen> {
  CallSession? _session;
  String? _room;
  String? _callId;
  RemoteBackend? _cachedRemote;
  Timer? _statusPoll;
  bool _completedCleanly = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final state = GoRouterState.of(context);
    final peerId = state.pathParameters['id'] ?? '';
    final isVideo = state.uri.queryParameters['video'] == '1';
    final serverRoom = state.uri.queryParameters['room'];
    final callId = state.uri.queryParameters['call'];
    if (_session != null) return;
    final backend = ref.read(backendProvider);
    final remote = backend.asRemote;
    if (remote == null) {
      // Offline demo mode: no server to mint tokens — honest message.
      return;
    }
    _room =
        serverRoom ?? 'call_${DateTime.now().millisecondsSinceEpoch}_$peerId';
    _callId = callId;
    final session = CallSession(
      api: remote.api,
      room: _room!,
      isVideo: isVideo,
      callId: callId,
    );
    _session = session;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) session.connect(peerId: peerId);
    });
    if (callId != null && _statusPoll == null) {
      _statusPoll = Timer.periodic(const Duration(milliseconds: 2500), (
        _,
      ) async {
        final remote = _cachedRemote;
        final cid = _callId;
        if (remote == null || cid == null || _session == null) return;
        if (_session!.phase == CallPhase.ended) return;
        try {
          final st = await remote.api.getCallStatus(cid);
          final status = st?['status'] as String?;
          if (status == 'declined' ||
              status == 'cancelled' ||
              status == 'ended' ||
              status == 'missed') {
            // Peer declined / hung up / never answered → clean up + leave.
            if (mounted) _hangUpAndPop(context, reason: status);
          }
        } catch (_) {}
      });
    }
  }

  @override
  void dispose() {
    _statusPoll?.cancel();
    // Leaving via back button while the invite still rings = cancel.
    final remote = _cachedRemote;
    final cid = _callId;
    final completedCleanly = _completedCleanly;
    if (!completedCleanly && remote != null && cid != null) {
      unawaited(remote.api.declineCall(cid).catchError((_) {}));
    }
    _session?.dispose();
    super.dispose();
  }

  Future<void> _hangUpAndPop(BuildContext context, {String? reason}) async {
    _completedCleanly = true;
    _statusPoll?.cancel();
    await _session?.hangUp();
    final remote = _cachedRemote;
    final callId = _callId;
    if (callId != null && remote != null) {
      if (reason != null) {
        // Peer-driven end: authoritative status already recorded server-side.
      } else {
        unawaited(remote.endCallById(callId));
      }
    }
    if (context.mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    _cachedRemote = ref.read(backendProvider).asRemote;
    final session = _session;
    if (session == null) return _notConfigured(context);

    return AnimatedBuilder(
      animation: session,
      builder: (context, _) {
        switch (session.phase) {
          case CallPhase.connecting:
            return _statusScaffold(
              context,
              session.isVideo ? 'Calling…' : 'Ringing…',
            );
          case CallPhase.reconnecting:
            return _statusScaffold(context, 'Reconnecting…');
          case CallPhase.failed:
            return _statusScaffold(
              context,
              session.error ?? 'Call failed',
              isError: true,
            );
          case CallPhase.ended:
            return _statusScaffold(context, 'Call ended');
          case CallPhase.connected:
            return _connected(context, session);
        }
      },
    );
  }

  Widget _notConfigured(BuildContext context) {
    return Scaffold(
      backgroundColor: Palette.bg,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.videocam_off_rounded,
                size: 46,
                color: Palette.textSecondary,
              ),
              const SizedBox(height: 16),
              const Text(
                'Calling needs the live app',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(
                'Calls connect through the UniCom server. Run the app in live '
                'mode (--dart-define=UNICOM_BASE_URL=…) with calling configured.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () => context.pop(),
                child: const Text('Back'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statusScaffold(
    BuildContext context,
    String label, {
    bool isError = false,
  }) {
    return Scaffold(
      backgroundColor: Palette.bg,
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(),
            Icon(
              isError
                  ? Icons.error_outline_rounded
                  : Icons.wifi_tethering_rounded,
              size: 46,
              color: isError ? Palette.danger : Palette.iris,
            ),
            const SizedBox(height: 16),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 26),
            if (!isError)
              const SizedBox(
                width: 26,
                height: 26,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.only(bottom: 40),
              child: _endButton(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _endButton(BuildContext context) => GestureDetector(
    onTap: () => _hangUpAndPop(context),
    child: Container(
      width: 64,
      height: 64,
      decoration: const BoxDecoration(
        color: Palette.danger,
        shape: BoxShape.circle,
      ),
      child: const Icon(Icons.call_end_rounded, color: Colors.white, size: 28),
    ),
  );

  Widget _connected(BuildContext context, CallSession session) {
    final backend = ref.read(backendProvider);
    final peerId = GoRouterState.of(context).pathParameters['id'] ?? '';
    final peer = backend.contactById(peerId);
    final remote = session.remoteParticipant;
    final remoteVideo = _videoTrack(remote);
    final localVideo = _videoTrack(session.localParticipant);

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            // Remote video (or avatar placeholder for audio calls).
            Positioned.fill(
              child:
                  session.isVideo && remoteVideo != null
                      ? lk.VideoTrackRenderer(remoteVideo)
                      : _audioBackdrop(context, peer?.name ?? 'Call'),
            ),
            // Local preview (PiP) for video calls.
            if (session.isVideo && localVideo != null)
              Positioned(
                right: 16,
                top: 16,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: SizedBox(
                    width: 110,
                    height: 150,
                    child: lk.VideoTrackRenderer(localVideo),
                  ),
                ),
              ),
            // Status + duration.
            Positioned(
              top: 18,
              left: 0,
              right: 0,
              child: Column(
                children: [
                  Text(
                    peer?.name ?? 'Call',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const SizedBox(height: 6),
                  if (session.isVideo && session.camDenied)
                    const Text(
                      'audio-only (camera unavailable)',
                      style: TextStyle(color: Colors.white60, fontSize: 12),
                    ),
                  Text(
                    _clock(session.duration),
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: .8),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            // Controls.
            Positioned(
              left: 0,
              right: 0,
              bottom: 34,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _round(
                    icon:
                        session.micEnabled
                            ? Icons.mic_rounded
                            : Icons.mic_off_rounded,
                    active: !session.micEnabled,
                    onTap: session.toggleMic,
                  ),
                  const SizedBox(width: 18),
                  if (session.isVideo) ...[
                    _round(
                      icon:
                          session.camEnabled
                              ? Icons.videocam_rounded
                              : Icons.videocam_off_rounded,
                      active: !session.camEnabled,
                      onTap: session.toggleCamera,
                    ),
                    const SizedBox(width: 18),
                    _round(
                      icon: Icons.cameraswitch_rounded,
                      onTap: session.switchCamera,
                    ),
                    const SizedBox(width: 18),
                  ],
                  _round(
                    icon: Icons.call_end_rounded,
                    danger: true,
                    onTap: () => _hangUpAndPop(context),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  lk.VideoTrack? _videoTrack(lk.Participant? p) {
    if (p == null) return null;
    for (final pub in p.videoTrackPublications) {
      final t = pub.track;
      if (t is lk.VideoTrack) return t;
    }
    return null;
  }

  Widget _audioBackdrop(BuildContext context, String name) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF0E2B29), Palette.bg],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            UserAvatar(name: name, size: 120, showOnline: false),
            const SizedBox(height: 18),
            Text(
              name,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _round({
    required IconData icon,
    required VoidCallback onTap,
    bool active = false,
    bool danger = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          color:
              danger
                  ? Palette.danger
                  : (active
                      ? Colors.white
                      : Colors.white.withValues(alpha: .14)),
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          color: danger ? Colors.white : (active ? Palette.bg : Colors.white),
          size: 26,
        ),
      ),
    );
  }

  String _clock(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}
