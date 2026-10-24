import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app.dart';
import '../../core/theme/palette.dart';
import '../../providers.dart';
import '../../shared/widgets/sheets.dart';
import '../../shared/widgets/ui_kit.dart';

/// Incoming call — caller identity from the peer id, accept routes to the
/// real LiveKit call; decline/remind/message are all real actions.
class IncomingCallScreen extends ConsumerWidget {
  const IncomingCallScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = GoRouterState.of(context);
    final id = state.pathParameters['id'] ?? '';
    final isVideo = state.uri.queryParameters['video'] == '1';
    final backend = ref.watch(backendProvider);

    // Null-safe identity resolution — never assume the directory is loaded
    // or that the id refers to a contact (it may be a conversation).
    final user = backend.contactById(id);
    final name = user?.name ?? 'Unknown caller';

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0E2B29), Palette.bg],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 18),
              Text(
                isVideo
                    ? 'Incoming video call — translated live'
                    : 'UniCom translated call — you speak, they hear theirs',
                maxLines: 2,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: .5),
                  fontSize: 12,
                ),
              ),
              const Spacer(flex: 3),
              if (user != null)
                UserAvatar(
                  name: user.name,
                  gradient: user.gradient,
                  userId: user.id,
                  imageUrl: user.avatarUrl,
                  size: 128,
                  showOnline: false,
                )
              else
                const Icon(
                  Icons.person_rounded,
                  color: Colors.white38,
                  size: 128,
                ),
              const SizedBox(height: 22),
              Text(
                name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.call_end_rounded,
                    size: 16,
                    color: Palette.danger,
                  ),
                  const SizedBox(width: 7),
                  Text(
                    isVideo ? 'Incoming video call' : 'Incoming voice call',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: .8),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const Spacer(flex: 4),
              Padding(
                padding: const EdgeInsets.fromLTRB(30, 0, 30, 30),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _CallAction(
                      icon: Icons.call_end_rounded,
                      background: Palette.danger,
                      label: 'Decline',
                      onTap: () => context.pop(),
                    ),
                    _CallAction(
                      icon:
                          isVideo ? Icons.videocam_rounded : Icons.call_rounded,
                      background: Palette.online,
                      label: 'Accept',
                      onTap: () {
                        if (id.isEmpty) {
                          infoToast(context, 'Cannot determine the caller');
                          return;
                        }
                        context.pop();
                        context.push(
                          '/call/live/$id${isVideo ? '?video=1' : ''}',
                        );
                      },
                    ),
                    _CallAction(
                      icon: Icons.chat_bubble_outline_rounded,
                      background: Colors.white24,
                      label: 'Message',
                      onTap: () {
                        if (user == null) {
                          infoToast(context, 'Unavailable in this context');
                          return;
                        }
                        final conv = backend.openWith(user);
                        context
                          ..pop()
                          ..push('/chat/${conv.id}');
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CallAction extends StatelessWidget {
  const _CallAction({
    required this.icon,
    required this.background,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final Color background;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Column(
        children: [
          Container(
            width: 62,
            height: 62,
            decoration: BoxDecoration(
              color: background,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white, size: 26),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: .85),
              fontWeight: FontWeight.w700,
              fontSize: 12.5,
            ),
          ),
        ],
      ),
    );
  }
}

/// Ringing overlay shown over any screen when a call arrives (driven by the
/// backend's ringing state). Accept joins the real room; decline notifies the
/// server so the caller stops ringing.
class IncomingCallOverlay extends ConsumerWidget {
  const IncomingCallOverlay({
    super.key,
    required this.callerId,
    required this.callId,
    required this.callType,
  });

  final String callerId;
  final String callId;
  final String callType;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final backend = ref.watch(backendProvider);
    final user = backend.contactById(callerId);
    final name = user?.name ?? 'Unknown caller';
    final isVideo = callType == 'video';

    return Material(
      color: Colors.black.withValues(alpha: .82),
      child: SafeArea(
        child: Column(
          children: [
            const Spacer(flex: 3),
            if (user != null)
              UserAvatar(
                name: user.name,
                gradient: user.gradient,
                userId: user.id,
                imageUrl: user.avatarUrl,
                size: 120,
                showOnline: false,
              )
            else
              const Icon(
                Icons.person_rounded,
                color: Colors.white38,
                size: 120,
              ),
            const SizedBox(height: 20),
            Text(
              name,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              isVideo ? 'Incoming video call…' : 'Incoming voice call…',
              style: TextStyle(
                color: Colors.white.withValues(alpha: .75),
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(flex: 2),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _OverlayAction(
                  icon: Icons.call_end_rounded,
                  background: Palette.danger,
                  label: 'Decline',
                  onTap: () => backend.asRemote?.declineCallById(callId),
                ),
                _OverlayAction(
                  icon: isVideo ? Icons.videocam_rounded : Icons.call_rounded,
                  background: Palette.online,
                  label: 'Accept',
                  onTap: () async {
                    final room = await backend.asRemote?.acceptCallById(callId);
                    // Navigate through the app's global navigator so the push
                    // can't be lost while this overlay unmounts.
                    final nav = callNavigatorKey.currentContext;
                    if (nav != null && nav.mounted) {
                      final q = [
                        if (room != null && room.isNotEmpty)
                          'room=${Uri.encodeComponent(room)}',
                        'call=$callId',
                        if (isVideo) 'video=1',
                      ].join('&');
                      nav.push('/call/live/$callerId?$q');
                    }
                  },
                ),
              ],
            ),
            const Spacer(),
          ],
        ),
      ),
    );
  }
}

class _OverlayAction extends StatelessWidget {
  const _OverlayAction({
    required this.icon,
    required this.background,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final Color background;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Column(
        children: [
          Container(
            width: 66,
            height: 66,
            decoration: BoxDecoration(
              color: background,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white, size: 28),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: .9),
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}
