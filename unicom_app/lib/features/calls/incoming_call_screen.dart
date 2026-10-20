import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/palette.dart';
import '../../providers.dart';
import '../../shared/widgets/sheets.dart';
import '../../shared/widgets/ui_kit.dart';

/// Incoming call — Chatbox kit: blurred dark teal ambience, huge avatar,
/// "Incoming voice call", slide-to-answer pill, Remind / Message actions.
class IncomingCallScreen extends ConsumerWidget {
  const IncomingCallScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = GoRouterState.of(context).pathParameters['id'] ?? 'usr_amara';
    final backend = ref.watch(backendProvider);
    final user = backend.contactById(id) ?? backend.contacts.first;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF290B3D), Palette.welcome2],
            stops: [0, 1],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 18),
              const Text(
                'UniCom translated call — you speak, they hear their language',
                maxLines: 2,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white54, fontSize: 12),
              ),
              const Spacer(flex: 3),
              UserAvatar(
                name: user.name,
                gradient: user.gradient,
                userId: user.id,
                imageUrl: user.avatarUrl,
                size: 128,
                showOnline: false,
                heroTag: 'call-avatar-${user.id}',
              ),
              const SizedBox(height: 22),
              Text(
                user.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -.4,
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
                    'Incoming voice call',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: .8),
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              const Spacer(flex: 4),
              LayoutBuilder(
                builder: (context, box) {
                  final railHeight = 260.0;
                  return SizedBox(
                    height: railHeight,
                    width: 320,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Column(
                          children: [
                            Container(
                              alignment: Alignment.topCenter,
                              padding: const EdgeInsets.symmetric(vertical: 22),
                              child: const Icon(
                                Icons.videocam_off_rounded,
                                color: Colors.white38,
                                size: 22,
                              ),
                            ),
                            Container(
                              width: 6,
                              height: railHeight - 90,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: .14),
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                            Container(
                              alignment: Alignment.bottomCenter,
                              padding: const EdgeInsets.symmetric(vertical: 18),
                              child: Icon(
                                Icons.mic_off_rounded,
                                color: Colors.white.withValues(alpha: .5),
                                size: 20,
                              ),
                            ),
                          ],
                        ),
                        Positioned(right: 18, child: SlideToAnswerRamp()),
                      ],
                    ),
                  );
                },
              ),
              const Spacer(flex: 2),
              Padding(
                padding: const EdgeInsets.fromLTRB(30, 0, 30, 30),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _CallAction(
                      icon: Icons.notifications_outlined,
                      label: 'Remind',
                      onTap: () {
                        infoToast(context, 'Call postponed (demo)');
                        context.pop();
                      },
                    ),
                    _CallAction(
                      icon: Icons.chat_bubble_outline_rounded,
                      label: 'Message',
                      onTap: () {
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

/// Rounded pill handle that swipes right-to-answer with interpolation.
class SlideToAnswerRamp extends StatefulWidget {
  const SlideToAnswerRamp({super.key});

  @override
  State<SlideToAnswerRamp> createState() => _SlideToAnswerRampState();
}

class _SlideToAnswerRampState extends State<SlideToAnswerRamp> {
  double _x = 0;

  @override
  Widget build(BuildContext context) {
    const max = 205.0;
    final knobColor = _x >= max * .98 ? Palette.online : Palette.danger;
    return GestureDetector(
      onHorizontalDragUpdate: (d) {
        setState(() => _x = (_x + d.delta.dx).clamp(0, max));
      },
      onHorizontalDragEnd: (details) {
        if (_x >= max * .97) {
          context.go('/call/live/diego');
        } else {
          setState(() => _x = 0);
        }
      },
      child: Stack(
        children: [
          Container(
            width: 254,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: _x == 0 ? .16 : .22),
              borderRadius: BorderRadius.circular(999),
            ),
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 18),
            child: Text(
              'Answer',
              style: TextStyle(
                color: Colors.white.withValues(alpha: .9),
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
          Transform.translate(
            offset: Offset(_x, 0),
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: knobColor,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.phone_rounded,
                color: Colors.white,
                size: 22,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CallAction extends StatelessWidget {
  const _CallAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
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
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white, size: 23),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: .8),
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
