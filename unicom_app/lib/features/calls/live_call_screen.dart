import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/palette.dart';
import '../../data/backend_base.dart';
import '../../providers.dart';
import '../../shared/widgets/sheets.dart';

/// Live call — Chatbox kit: deep purple gradient, translucent controls,
/// timer counting up, translation status chip, PiP self-view, end-call red.
class LiveCallScreen extends ConsumerStatefulWidget {
  const LiveCallScreen({super.key});

  @override
  ConsumerState<LiveCallScreen> createState() => _LiveCallScreenState();
}

class _LiveCallScreenState extends ConsumerState<LiveCallScreen> {
  Timer? _clock;
  Duration _elapsed = Duration.zero;
  bool _muted = false;
  bool _speakerOn = true;

  @override
  void initState() {
    super.initState();
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _elapsed += const Duration(seconds: 1));
    });
  }

  @override
  void dispose() {
    _clock?.cancel();
    super.dispose();
  }

  String _peerName(UniBackend backend) {
    final me = backend.me?.name ?? 'You';
    return me;
  }

  @override
  Widget build(BuildContext context) {
    final backend = ref.watch(backendProvider);
    final me = backend.me;
    final name =
        me != null && backend.conversations.isNotEmpty
            ? _peerName(backend)
            : 'You';

    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF2E0C42), Palette.welcome2],
            stops: [0, 1],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              Column(
                children: [
                  const SizedBox(height: 26),
                  // Auto-translation chip
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 13,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: .1),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.translate_rounded,
                          size: 14,
                          color: Palette.teal03,
                        ),
                        const SizedBox(width: 7),
                        Text(
                          'Live translation on — speech output in your language',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: .85),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -.3,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '00:${_elapsed.inMinutes.toString().padLeft(2, '0')}:${_elapsed.inSeconds.remainder(60).toString().padLeft(2, '0')}',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: .7),
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Container(
                    margin: const EdgeInsets.symmetric(vertical: 18),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 9,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: .07),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.graphic_eq_rounded,
                          size: 15,
                          color: Palette.teal03,
                        ),
                        SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            '🎙 Translating Amara → your language…',
                            maxLines: 1,
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: Colors.white70,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(flex: 3),
                  // Volume slider
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 5,
                      overlayShape: const RoundSliderOverlayShape(
                        overlayRadius: 19,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 40),
                      child: Slider(
                        value: .62,
                        onChanged: (_) {},
                        activeColor: Colors.white.withValues(alpha: .9),
                        inactiveColor: Colors.white.withValues(alpha: .2),
                        thumbColor: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),
                  // Control cluster
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _BigRoundIcon(
                          icon:
                              _muted
                                  ? Icons.mic_off_rounded
                                  : Icons.mic_rounded,
                          filled: _muted,
                          onTap: () => setState(() => _muted = !_muted),
                        ),
                        _BigRoundIcon(
                          icon:
                              _speakerOn
                                  ? Icons.volume_up_rounded
                                  : Icons.volume_off_rounded,
                          onTap: () => setState(() => _speakerOn = !_speakerOn),
                        ),
                        _BigRoundIcon(
                          icon: Icons.videocam_rounded,
                          onTap: () {
                            infoToast(context, 'Switching video (demo)');
                          },
                        ),
                        _BigRoundIcon(
                          icon: Icons.call_end_rounded,
                          filled: true,
                          isDanger: true,
                          onTap: () => context.pop(),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 36),
                ],
              ),
              // PiP self-view
              Positioned(
                right: 20,
                top: 24,
                child: Container(
                  width: 72,
                  height: 100,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    gradient: Palette.brand,
                    border: Border.all(color: Colors.white24),
                  ),
                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.person_outline_rounded,
                        color: Colors.white,
                        size: 26,
                      ),
                      SizedBox(height: 4),
                      Text(
                        'LIVE',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BigRoundIcon extends StatelessWidget {
  const _BigRoundIcon({
    required this.icon,
    required this.onTap,
    this.filled = false,
    this.isDanger = false,
  });

  final IconData icon;
  final VoidCallback onTap;
  final bool filled;
  final bool isDanger;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Container(
        width: 58,
        height: 58,
        decoration: BoxDecoration(
          color:
              filled
                  ? (isDanger ? Palette.danger : Colors.white)
                  : Colors.white.withValues(alpha: .1),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 24),
      ),
    );
  }
}
