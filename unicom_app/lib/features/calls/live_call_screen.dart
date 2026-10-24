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
              video: session.isVideo,
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
    bool video = false,
  }) {
    final backend = ref.read(backendProvider);
    final peerId = GoRouterState.of(context).pathParameters['id'] ?? '';
    final peer = backend.contactById(peerId);
    final name = peer?.name ?? 'Connecting';
    return Scaffold(
      backgroundColor: Palette.bg,
      body: SafeArea(
        child: Stack(
          children: [
            // Soft radial ambience
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(0, -0.4),
                    radius: 1.1,
                    colors: [Palette.iris.withValues(alpha: .18), Palette.bg],
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: LayoutBuilder(
                builder: (context, c) {
                  // Keep content centered within the safe area on every
                  // viewport; scroll instead of overflow on short/landscape.
                  final compact = c.maxHeight < 520;
                  return SingleChildScrollView(
                    physics:
                        compact
                            ? const ClampingScrollPhysics()
                            : const NeverScrollableScrollPhysics(),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minHeight: c.maxHeight),
                      child: Column(
                        children: [
                          SizedBox(height: compact ? 12 : 40),
                          // Pulsing avatar
                          if (peer != null)
                            _PulsingAvatar(
                              child: UserAvatar(
                                name: peer.name,
                                gradient: peer.gradient,
                                userId: peer.id,
                                imageUrl: peer.avatarUrl,
                                size: 128,
                                showOnline: false,
                              ),
                              active: !isError,
                            )
                          else
                            const Icon(
                              Icons.person_rounded,
                              color: Colors.white38,
                              size: 128,
                            ),
                          const SizedBox(height: 26),
                          Text(
                            name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -.4,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isError
                                    ? Icons.error_outline_rounded
                                    : (video
                                        ? Icons.videocam_rounded
                                        : Icons.phone_rounded),
                                size: 16,
                                color:
                                    isError
                                        ? Palette.danger
                                        : Palette.textSecondary,
                              ),
                              const SizedBox(width: 7),
                              Text(
                                label,
                                style: TextStyle(
                                  color:
                                      isError
                                          ? Palette.danger
                                          : Colors.white.withValues(alpha: .8),
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          if (!isError) ...[
                            const SizedBox(height: 22),
                            const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.2,
                              ),
                            ),
                          ],
                          SizedBox(height: compact ? 28 : 90),
                          _endButton(context),
                          const SizedBox(height: 14),
                          Text(
                            'End call',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: .7),
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SizedBox(height: compact ? 20 : 44),
                        ],
                      ),
                    ),
                  );
                },
              ),
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
            // Remote video is the primary surface. Distinguish real video from
            // the honest "waiting / camera off" states so a black tile never
            // masquerades as a connected video feed.
            Positioned.fill(
              child:
                  session.isVideo && remoteVideo != null
                      ? lk.VideoTrackRenderer(remoteVideo)
                      : _audioBackdrop(
                        context,
                        peer?.name ?? 'Call',
                        status: session.isVideo ? 'Video is off' : null,
                      ),
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
                    child: lk.VideoTrackRenderer(
                      localVideo,
                      key: ValueKey('local-${localVideo.sid}'),
                      mirrorMode:
                          session.localParticipant != null
                              ? lk.VideoViewMirrorMode.mirror
                              : lk.VideoViewMirrorMode.mirror,
                    ),
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
                  // Speaker / earpiece — drives the real Android/iOS route.
                  _round(
                    icon:
                        session.speakerOn
                            ? Icons.volume_up_rounded
                            : Icons.volume_down_rounded,
                    active: !session.speakerOn,
                    onTap: session.toggleSpeaker,
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

  Widget _audioBackdrop(BuildContext context, String name, {String? status}) {
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
            if (status != null) ...[
              const SizedBox(height: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.videocam_off_rounded,
                    size: 16,
                    color: Colors.white54,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    status,
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
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

/// Gentle expanding-ring pulse behind the avatar while a call is connecting.
/// Purely decorative and cheap: two rings, no blur, no particles.
class _PulsingAvatar extends StatefulWidget {
  const _PulsingAvatar({required this.child, required this.active});
  final Widget child;
  final bool active;

  @override
  State<_PulsingAvatar> createState() => _PulsingAvatarState();
}

class _PulsingAvatarState extends State<_PulsingAvatar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 190,
      height: 190,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (widget.active)
            AnimatedBuilder(
              animation: _c,
              builder: (context, _) {
                final t = _c.value;
                return CustomPaint(
                  size: const Size(190, 190),
                  painter: _RingPulsePainter(progress: t, color: Palette.iris),
                );
              },
            ),
          widget.child,
        ],
      ),
    );
  }
}

class _RingPulsePainter extends CustomPainter {
  _RingPulsePainter({required this.progress, required this.color});
  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    for (final phase in [0.0, 0.5]) {
      final p = (progress + phase) % 1.0;
      final radius = 64 + p * 28;
      final paint =
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..color = color.withValues(alpha: (1 - p) * 0.35);
      canvas.drawCircle(center, radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _RingPulsePainter old) =>
      old.progress != progress;
}
