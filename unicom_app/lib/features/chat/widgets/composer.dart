import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/audio/recording_service.dart';
import '../../../core/theme/palette.dart';
import 'recorder_overlay.dart';

/// Message composer — paperclip opens the Share-Content sheet, a roomy pill
/// input with a sticker glyph inside, then mic. Typed text morphs the mic
/// into a teal send bubble.
class Composer extends StatefulWidget {
  const Composer({
    super.key,
    required this.onSendText,
    required this.onSendVoice,
    required this.enabled,
    this.onDemoVoice,
    this.onShare,
    this.onTyping,
    this.initialDraft = '',
  });

  final ValueChanged<String> onSendText;
  final void Function(RecordingResult result) onSendVoice;
  final Future<void> Function(Duration duration)? onDemoVoice;
  final bool enabled;
  final VoidCallback? onShare;
  final VoidCallback? onTyping;
  final String initialDraft;

  @override
  State<Composer> createState() => _ComposerState();
}

class _ComposerState extends State<Composer> {
  late final TextEditingController _c = TextEditingController(
    text: widget.initialDraft,
  );
  final FocusNode _focus = FocusNode();
  Timer? _typingDebounce;

  @override
  void dispose() {
    _typingDebounce?.cancel();
    _c.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _send() {
    final text = _c.text.trim();
    if (text.isEmpty) return;
    widget.onSendText(text);
    _c.clear();
  }

  void _openRecorder() {
    if (!widget.enabled) return;
    Navigator.of(context).push(
      PageRouteBuilder<void>(
        opaque: false,
        barrierColor: Colors.black54,
        pageBuilder:
            (_, _, _) => RecorderOverlay(
              onSend: (result) async => widget.onSendVoice(result),
              demoFallback: widget.onDemoVoice,
            ),
        transitionsBuilder:
            (_, anim, _, child) => FadeTransition(opacity: anim, child: child),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = scheme.brightness == Brightness.dark;
    final hasText = _c.text.trim().isNotEmpty;

    Widget kiteButton(IconData icon, {VoidCallback? onTap, Color? color}) =>
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color ?? (dark ? Colors.white10 : Colors.white),
              border: Border.all(
                color:
                    (color ?? (dark ? Colors.white24 : Palette.lightOutline2)),
              ),
            ),
            child: Icon(
              icon,
              size: 19,
              color:
                  color == null
                      ? (dark ? Colors.white70 : Palette.lightMuted)
                      : Colors.white,
            ),
          ),
        );

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      decoration: BoxDecoration(
        color: dark ? Palette.bg2 : Palette.lightSurface,
        border: Border(
          top: BorderSide(color: dark ? Palette.border : Palette.lightOutline),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            kiteButton(
              Icons.attach_file_rounded,
              onTap: () {
                if (widget.onShare == null) return;
                widget.onShare!();
              },
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _c,
                focusNode: _focus,
                minLines: 1,
                maxLines: 5,
                textInputAction: TextInputAction.newline,
                enabled: widget.enabled,
                onChanged: (_) {
                  setState(() {});
                  if (_c.text.isNotEmpty) {
                    _typingDebounce?.cancel();
                    _typingDebounce = Timer(
                      const Duration(milliseconds: 600),
                      () => widget.onTyping?.call(),
                    );
                  }
                },
                style: const TextStyle(
                  fontSize: 14.6,
                  fontWeight: FontWeight.w500,
                ),
                decoration: InputDecoration(
                  hintText: 'Message…',
                  isDense: true,
                  contentPadding: const EdgeInsets.fromLTRB(18, 12, 4, 12),
                  suffixIcon: Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: Icon(
                      Icons.face_retouching_natural_rounded,
                      size: 20,
                      color: scheme.onSurfaceVariant.withValues(alpha: .55),
                    ),
                  ),
                  suffixIconConstraints: const BoxConstraints(minWidth: 42),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  fillColor: dark ? Palette.darkCard2 : const Color(0xFFF0F2F3),
                  filled: true,
                ),
              ),
            ),
            const SizedBox(width: 8),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              switchInCurve: Curves.easeOutBack,
              transitionBuilder:
                  (child, anim) => ScaleTransition(scale: anim, child: child),
              child:
                  hasText
                      ? _RoundAction(
                        key: const ValueKey('send'),
                        color: Palette.cyan,
                        icon: Icons.arrow_upward_rounded,
                        iconColor: const Color(0xFF00232B),
                        onTap: _send,
                      )
                      : _RoundAction(
                        key: const ValueKey('mic'),
                        color: Palette.orange,
                        icon: Icons.mic_rounded,
                        onTap: _openRecorder,
                      ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoundAction extends StatelessWidget {
  const _RoundAction({
    super.key,
    required this.icon,
    required this.color,
    this.iconColor = Colors.white,
    this.onTap,
  });

  final IconData icon;
  final Color color;
  final Color iconColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: icon == Icons.mic_rounded ? 'Record voice note' : 'Send message',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          child: Icon(icon, color: iconColor, size: 22),
        ),
      ),
    );
  }
}
