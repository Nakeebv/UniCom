import 'package:flutter/material.dart';

import '../../../core/theme/palette.dart';
import '../../../core/theme/theme.dart';
import '../../../core/utils.dart';
import '../../../data/models/language.dart';
import '../../../data/models/message.dart';
import '../../../features/chats/chats_screen.dart' show DeliveryGlyph;
import '../../../shared/widgets/ui_kit.dart';
import 'voice_bubble.dart';

/// One message row: sender bubble with translation-state machinery.
///
/// Incoming bubble shows the translated text as primary content with the
/// original one tap away — or graceful fallback states when translation
/// is processing / unavailable. Outgoing bubbles show original text plus
/// the translation status for the recipient's language.
class MessageBubble extends StatefulWidget {
  const MessageBubble({
    super.key,
    required this.message,
    required this.viewerId,
    required this.targetLanguage,
    required this.otherName,
    required this.otherGradient,
    required this.onRetryTranslation,
    required this.onLongPress,
    this.onTapAvatar,
    this.isGroupTail = true,
    this.onVotePoll,
    this.senderNameLabel,
    this.showSenderName = false,
    this.otherAvatarUrl,
  });

  final Message message;
  final String viewerId;
  final String targetLanguage;
  final String otherName;
  final Gradient otherGradient;
  final VoidCallback onRetryTranslation;
  final VoidCallback onLongPress;
  final VoidCallback? onTapAvatar;
  final bool isGroupTail;

  /// Poll option tap (votes, only for messages I didn't create).
  final void Function(int optionIndex)? onVotePoll;

  /// Group attribution shown above the bubble (kin sends with a name).
  final String? senderNameLabel;
  final bool showSenderName;

  /// Real avatar URL of the message sender (group attribution).
  final String? otherAvatarUrl;

  @override
  State<MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<MessageBubble> {
  bool _showOriginal = false;

  bool get mine => widget.message.senderId == widget.viewerId;

  @override
  Widget build(BuildContext context) {
    final m = widget.message;
    if (m.deleted) {
      return _deletedRow();
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Column(
        crossAxisAlignment:
            mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          if (widget.showSenderName && !mine && widget.senderNameLabel != null)
            Padding(
              padding: const EdgeInsets.only(left: 40, bottom: 3),
              child: Text(
                widget.senderNameLabel!,
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  color: Palette.iris,
                ),
              ),
            ),
          Row(
            mainAxisAlignment:
                mine ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (!mine) _avatar(context),
              Flexible(
                child: AnimatedSize(
                  duration: const Duration(milliseconds: 260),
                  curve: Curves.easeOutCubic,
                  alignment:
                      mine ? Alignment.bottomRight : Alignment.bottomLeft,
                  child: GestureDetector(
                    onLongPress: widget.onLongPress,
                    child: Container(
                      constraints: BoxConstraints(
                        maxWidth:
                            Layout.isExpanded(context)
                                ? Layout.maxBubbleWidth
                                : MediaQuery.sizeOf(context).width * .78,
                      ),
                      padding: const EdgeInsets.fromLTRB(14, 10, 14, 9),
                      decoration: BoxDecoration(
                        color:
                            mine
                                ? (Theme.of(context).brightness ==
                                        Brightness.dark
                                    ? Palette.bubbleOut
                                    : Palette.bubbleOutLight)
                                : (Theme.of(context).brightness ==
                                        Brightness.dark
                                    ? Palette.darkBubbleIn
                                    : Palette.lightBubbleIn),
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(mine ? 18 : 6),
                          topRight: Radius.circular(mine ? 6 : 18),
                          bottomLeft: const Radius.circular(18),
                          bottomRight: const Radius.circular(18),
                        ),
                        border:
                            mine
                                ? Border.all(
                                  color: Palette.cyan.withValues(alpha: .22),
                                )
                                : Border.all(
                                  color: Palette.border.withValues(alpha: .6),
                                ),
                      ),
                      child:
                          m.kind == MessageKind.voice
                              ? _voiceBody()
                              : m.kind == MessageKind.poll
                              ? _pollBody()
                              : _textBody(),
                    ),
                  ),
                ),
              ),
              if (mine) ...[
                const SizedBox(width: 6),
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: DeliveryGlyph(state: m.delivery),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _avatar(BuildContext context) {
    if (!widget.isGroupTail) {
      return const SizedBox(width: 30);
    }
    return Padding(
      padding: const EdgeInsets.only(right: 8, bottom: 2),
      child: GestureDetector(
        onTap: widget.onTapAvatar,
        child: UserAvatar(
          name: widget.otherName,
          gradient: widget.otherGradient,
          userId: widget.message.senderId,
          imageUrl: widget.otherAvatarUrl,
          size: 30,
          showOnline: false,
          heroTag: 'chat-avatar-${widget.message.senderId}',
        ),
      ),
    );
  }

  Widget _deletedRow() {
    final scheme = Theme.of(context).colorScheme;
    return Align(
      alignment:
          widget.message.senderId == widget.viewerId
              ? Alignment.centerRight
              : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 3),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: scheme.onSurfaceVariant.withValues(alpha: .08),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.block_rounded, size: 13, color: scheme.onSurfaceVariant),
            const SizedBox(width: 6),
            Text(
              'Message deleted',
              style: TextStyle(
                fontSize: 12,
                fontStyle: FontStyle.italic,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Voice ────────────────────────────────────────────────────────────────
  Widget _voiceBody() {
    return VoiceBubbleView(
      voice: widget.message.voice!,
      sourceLanguage: widget.message.sourceLanguage,
      targetLanguage: widget.targetLanguage,
      isMine: mine,
      createdAt: widget.message.createdAt,
      onRetry: widget.onRetryTranslation,
    );
  }

  // ── Poll ──────────────────────────────────────────────────────────────────
  Widget _pollBody() {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final m = widget.message;
    final poll = m.poll!;
    final total = poll.votes.values.fold<int>(0, (sum, l) => sum + l.length);
    final chipBg =
        mine
            ? Colors.white.withValues(alpha: .16)
            : (dark ? Palette.darkCard2 : Colors.white);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color:
                    mine
                        ? Colors.white.withValues(alpha: .18)
                        : Palette.chipMint,
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(
                Icons.poll_rounded,
                size: 16,
                color: mine ? Colors.white : Palette.chipMintInk,
              ),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                poll.question,
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                  height: 1.3,
                  color:
                      mine
                          ? Colors.white
                          : (dark ? Palette.darkInk : Palette.lightInk),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        for (var i = 0; i < poll.options.length; i++)
          _pollOption(poll, i, total, chipBg),
        const SizedBox(height: 7),
        Text(
          total == 0
              ? 'No votes yet — tap to vote'
              : '$total vote${total == 1 ? '' : 's'}',
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            color:
                mine
                    ? Colors.white.withValues(alpha: .65)
                    : (dark ? Palette.darkMuted : Palette.lightMuted),
          ),
        ),
      ],
    );
  }

  Widget _pollOption(PollPayload poll, int i, int total, Color chipBg) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final count = poll.votes[i]?.length ?? 0;
    final fraction = total == 0 ? 0.0 : count / total;
    final isMine = poll.myVote == i;
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: GestureDetector(
        onTap: () => widget.onVotePoll?.call(i),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Stack(
            children: [
              // Tally fill
              Positioned.fill(
                child: AnimatedFractionallySizedBox(
                  duration: const Duration(milliseconds: 380),
                  curve: Curves.easeOutCubic,
                  alignment: Alignment.centerLeft,
                  widthFactor: fraction,
                  child: Container(
                    color:
                        mine
                            ? Colors.white.withValues(alpha: .22)
                            : Palette.chipMint,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.fromLTRB(10, 9, 10, 9),
                child: Row(
                  children: [
                    Icon(
                      isMine
                          ? Icons.check_circle_rounded
                          : Icons.radio_button_unchecked_rounded,
                      size: 16,
                      color:
                          mine
                              ? Colors.white
                              : (isMine ? Palette.iris : Palette.lightMuted),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        poll.options[i],
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight:
                              isMine ? FontWeight.w800 : FontWeight.w600,
                          color:
                              mine
                                  ? Colors.white
                                  : (dark ? Palette.darkInk : Palette.lightInk),
                        ),
                      ),
                    ),
                    Text(
                      '$count',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        color:
                            mine
                                ? Colors.white.withValues(alpha: .85)
                                : Palette.iris,
                      ),
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

  // ── Text ─────────────────────────────────────────────────────────────────
  Widget _textBody() {
    final m = widget.message;
    final t = m.translations[widget.targetLanguage];
    final sameLang = m.sourceLanguage == widget.targetLanguage;

    // ── Outgoing: original text + recipient-language status ────────────────
    if (mine) {
      if (sameLang || t == null) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [_originalText(), _meta()],
        );
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _originalText(),
          const SizedBox(height: 6),
          _outgoingTranslationStatus(t),
          _meta(),
        ],
      );
    }

    // ── Incoming ───────────────────────────────────────────────────────────
    if (sameLang) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [_originalText(), _meta(incoming: true)],
      );
    }

    switch (t?.status ?? TranslationStatus.none) {
      case TranslationStatus.none:
      case TranslationStatus.queued:
      case TranslationStatus.translating:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _shimmerBody(),
            _meta(incoming: true, state: TranslatingChipState.working),
          ],
        );
      case TranslationStatus.completed:
        final translated = t!.text ?? m.text ?? '';
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 240),
              child:
                  _showOriginal
                      ? _originalText(key: const ValueKey('orig'))
                      : _translatedText(translated, key: const ValueKey('tr')),
            ),
            const SizedBox(height: 6),
            _originalToggle(translated: translated),
            _meta(incoming: true, state: TranslatingChipState.done),
          ],
        );
      case TranslationStatus.unavailable:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _originalText(),
            const SizedBox(height: 6),
            _unavailableNote(),
            _meta(incoming: true, state: TranslatingChipState.unavailable),
          ],
        );
    }
  }

  // ── Pieces ───────────────────────────────────────────────────────────────
  Widget _originalText({Key? key}) {
    final mine = this.mine;
    return Text(
      widget.message.text ?? '',
      key: key,
      style: TextStyle(
        fontSize: 14.6,
        height: 1.42,
        fontWeight: FontWeight.w500,
        color: mine ? Colors.white : Theme.of(context).colorScheme.onSurface,
      ),
    );
  }

  Widget _translatedText(String text, {Key? key}) {
    return Text(
      text,
      key: key,
      style: const TextStyle(
        fontSize: 14.6,
        height: 1.42,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _shimmerBody() {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ShimmerBox(width: 190, height: 11),
        SizedBox(height: 7),
        ShimmerBox(width: 140, height: 11),
        SizedBox(height: 4),
      ],
    );
  }

  Widget _originalToggle({required String translated}) {
    final source = LanguageRegistry.of(widget.message.sourceLanguage);
    return Align(
      alignment: Alignment.centerLeft,
      child: Material(
        color: Palette.iris.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(999),
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: () => setState(() => _showOriginal = !_showOriginal),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4.5),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _showOriginal
                      ? Icons.language_rounded
                      : Icons.translate_rounded,
                  size: 12.5,
                  color: Palette.irisDark,
                ),
                const SizedBox(width: 5),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: Text(
                    _showOriginal
                        ? 'Translated'
                        : 'Original · ${source.nativeName}',
                    key: ValueKey(_showOriginal),
                    style: const TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      color: Palette.irisDark,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _unavailableNote() {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: Palette.warning.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.info_outline_rounded,
            size: 13,
            color: Color(0xFFB45309),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              'Translation unavailable — showing original',
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color:
                    scheme.brightness == Brightness.dark
                        ? const Color(0xFFFCD34D)
                        : const Color(0xFF92400E),
              ),
            ),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: widget.onRetryTranslation,
            child: const Text(
              'Retry',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: Palette.irisDark,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _outgoingTranslationStatus(Translation t) {
    final target = LanguageRegistry.of(widget.targetLanguage);
    return switch (t.status) {
      TranslationStatus.translating ||
      TranslationStatus.queued ||
      TranslationStatus.none => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 10,
            height: 10,
            child: CircularProgressIndicator(
              strokeWidth: 1.5,
              valueColor: AlwaysStoppedAnimation(
                Colors.white.withValues(alpha: .8),
              ),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '→ ${target.nativeName}…',
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: Colors.white.withValues(alpha: .8),
            ),
          ),
        ],
      ),
      TranslationStatus.unavailable => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.info_outline_rounded,
            size: 12,
            color: Color(0xFFFCD34D),
          ),
          const SizedBox(width: 5),
          Text(
            '→ ${target.nativeName} unavailable',
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: Colors.white.withValues(alpha: .75),
            ),
          ),
        ],
      ),
      TranslationStatus.completed => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.check_circle_rounded,
            size: 12,
            color: Color(0xFFA7F3D0),
          ),
          const SizedBox(width: 5),
          Text(
            'Delivered in ${target.nativeName}',
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: Colors.white.withValues(alpha: .82),
            ),
          ),
        ],
      ),
    };
  }

  Widget _meta({bool incoming = false, TranslatingChipState? state}) {
    final color =
        mine
            ? Colors.white.withValues(alpha: .62)
            : Theme.of(context).colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.only(top: 5),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            formatClock(widget.message.createdAt),
            style: TextStyle(fontSize: 10, color: color),
          ),
          if (widget.message.editedAt != null) ...[
            const SizedBox(width: 5),
            Text(
              'edited',
              style: TextStyle(
                fontSize: 10,
                fontStyle: FontStyle.italic,
                color: color,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

enum TranslatingChipState { working, done, unavailable }
