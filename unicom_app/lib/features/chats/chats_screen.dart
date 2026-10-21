import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/palette.dart';
import '../../core/theme/theme.dart';
import '../../core/utils.dart';
import '../../data/models/conversation.dart';
import '../../data/models/message.dart';
import '../../data/models/user.dart';
import '../../providers.dart';
import '../../shared/widgets/sheets.dart';
import '../../shared/widgets/ui_kit.dart';

/// Filter options for the conversation inbox.
enum _InboxFilter { all, unread, groups }

/// Home tab — UniCom dark inbox.
///
/// Compact, information-dense conversation list on a near-black surface:
/// search, filter chips (All · Unread · Groups — backed by real data),
/// circular avatars, translation-aware previews, unread badges and
/// delivery/voice/translation indicators. Swipe right = mute, left = clear.
class ChatsScreen extends ConsumerStatefulWidget {
  const ChatsScreen({super.key});

  @override
  ConsumerState<ChatsScreen> createState() => _ChatsScreenState();
}

class _ChatsScreenState extends ConsumerState<ChatsScreen> {
  String _query = '';
  final Set<String> _muted = {};
  _InboxFilter _filter = _InboxFilter.all;
  bool _searchOpen = false;

  @override
  Widget build(BuildContext context) {
    final backend = ref.watch(backendProvider);
    final me = backend.me;
    if (me == null) return const SizedBox.shrink();

    final all = backend.conversations;

    // Real search over names, group titles, previews and message text.
    final q = _query.trim().toLowerCase();
    var filtered =
        q.isEmpty
            ? all
            : all.where((c) {
              if ((c.displayTitle ?? '').toLowerCase().contains(q)) return true;
              for (final m in backend.messagesOf(c.id)) {
                if ((m.text ?? '').toLowerCase().contains(q)) return true;
              }
              return false;
            }).toList();

    switch (_filter) {
      case _InboxFilter.unread:
        filtered =
            filtered.where((c) => backend.unreadCount(c.id) > 0).toList();
      case _InboxFilter.groups:
        filtered = filtered.where((c) => c.isGroup).toList();
      case _InboxFilter.all:
        break;
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: Layout.maxContentWidth + 240,
            ),
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(child: _header(context, me)),
                if (_searchOpen) SliverToBoxAdapter(child: _searchField()),
                SliverToBoxAdapter(child: _filters()),
                if (filtered.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: EmptyState(
                      icon:
                          q.isNotEmpty || _filter != _InboxFilter.all
                              ? Icons.search_off_rounded
                              : Icons.forum_outlined,
                      title:
                          q.isNotEmpty
                              ? 'No results for “$_query”'
                              : _filter == _InboxFilter.unread
                              ? 'You’re all caught up'
                              : _filter == _InboxFilter.groups
                              ? 'No group chats yet'
                              : 'No conversations yet',
                      subtitle:
                          q.isNotEmpty
                              ? 'Try a different name, group or message.'
                              : 'Start a chat from Contacts and UniCom will '
                                  'translate everything into your language.',
                      action:
                          (q.isNotEmpty || _filter != _InboxFilter.all)
                              ? TextButton(
                                onPressed:
                                    () => setState(() {
                                      _query = '';
                                      _filter = _InboxFilter.all;
                                    }),
                                child: const Text('Clear filters'),
                              )
                              : null,
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(6, 0, 6, 96),
                    sliver: SliverList.builder(
                      itemCount: filtered.length,
                      itemBuilder: (context, i) {
                        final c = filtered[i];
                        return Dismissible(
                          key: ValueKey('swipe-${c.id}'),
                          background: _swipeBackground(
                            alignment: CrossAxisAlignment.start,
                            color: Palette.orange,
                            icon: Icons.notifications_off_rounded,
                            label: 'Mute',
                          ),
                          secondaryBackground: _swipeBackground(
                            alignment: CrossAxisAlignment.end,
                            color: Palette.dangerSoft,
                            icon: Icons.delete_outline_rounded,
                            label: 'Clear',
                            ink: Palette.danger,
                          ),
                          onDismissed: (_) {},
                          confirmDismiss: (direction) async {
                            if (direction == DismissDirection.startToEnd) {
                              setState(() => _muted.add(c.id));
                              if (context.mounted) {
                                await infoToast(context, 'Notifications muted');
                              }
                              return false;
                            }
                            final ok = await confirmDialog(
                              context,
                              title: 'Clear ${c.displayTitle ?? 'chat'}?',
                              message:
                                  'All messages in this conversation will be '
                                  'removed. The chat itself stays in your list.',
                              confirmLabel: 'Clear',
                              danger: true,
                            );
                            if (ok) backend.clearConversation(c.id);
                            return false;
                          },
                          child: ConversationTile(
                            conversation: c,
                            muted: _muted.contains(c.id),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _header(BuildContext context, UserProfile me) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(Layout.px, 10, Layout.px, 6),
      child: Row(
        children: [
          // Wordmark
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              gradient: Palette.brand,
              borderRadius: BorderRadius.circular(11),
            ),
            child: const Icon(
              Icons.translate_rounded,
              color: Color(0xFF00232B),
              size: 19,
            ),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Messages',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
            ),
          ),
          _HeaderIcon(
            icon: Icons.search_rounded,
            active: _searchOpen,
            label: 'Search',
            onTap: () => setState(() => _searchOpen = !_searchOpen),
          ),
          const SizedBox(width: 4),
          _HeaderIcon(
            icon: Icons.edit_square,
            label: 'New conversation',
            onTap: () => context.go('/contacts'),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: () => context.push('/settings/profile'),
            child: UserAvatar(
              name: me.name,
              gradient: me.gradient,
              userId: me.id,
              imageUrl: me.avatarUrl,
              size: 34,
              showOnline: false,
            ),
          ),
        ],
      ),
    );
  }

  Widget _searchField() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(Layout.px, 6, Layout.px, 2),
      child: TextField(
        autofocus: true,
        onChanged: (v) => setState(() => _query = v),
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: 'Search conversations…',
          prefixIcon: const Icon(Icons.search_rounded, size: 20),
          suffixIcon:
              _query.isEmpty
                  ? null
                  : IconButton(
                    icon: const Icon(Icons.close_rounded, size: 18),
                    onPressed: () => setState(() => _query = ''),
                  ),
        ),
      ),
    );
  }

  Widget _filters() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(Layout.px, 10, 0, 6),
      child: SizedBox(
        height: 36,
        child: ListView(
          scrollDirection: Axis.horizontal,
          children: [
            for (final f in _InboxFilter.values) ...[
              _FilterChip(
                label: switch (f) {
                  _InboxFilter.all => 'All',
                  _InboxFilter.unread => 'Unread',
                  _InboxFilter.groups => 'Groups',
                },
                selected: _filter == f,
                onTap: () => setState(() => _filter = f),
              ),
              const SizedBox(width: 8),
            ],
            const SizedBox(width: Layout.px),
          ],
        ),
      ),
    );
  }

  Widget _swipeBackground({
    required CrossAxisAlignment alignment,
    required Color color,
    required IconData icon,
    required String label,
    Color ink = Colors.white,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(Layout.rLg),
      ),
      child: Row(
        mainAxisAlignment:
            alignment == CrossAxisAlignment.start
                ? MainAxisAlignment.start
                : MainAxisAlignment.end,
        children: [
          if (alignment == CrossAxisAlignment.start) const SizedBox(width: 22),
          Icon(icon, color: ink),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: ink,
              fontWeight: FontWeight.w800,
              fontSize: 13,
            ),
          ),
          if (alignment == CrossAxisAlignment.end) const SizedBox(width: 22),
        ],
      ),
    );
  }
}

class _HeaderIcon extends StatelessWidget {
  const _HeaderIcon({
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: InkResponse(
        onTap: onTap,
        radius: 24,
        child: Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          child: Icon(
            icon,
            size: 22,
            color: active ? Palette.cyan : Palette.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? Palette.cyanSoft : Palette.darkCard,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: selected ? Palette.cyan : Palette.border),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: selected ? Palette.cyan : Palette.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

/// One conversation row — circular avatar, name, translation-aware preview,
/// timestamp, unread badge, delivery / voice / translation indicators.
class ConversationTile extends ConsumerWidget {
  const ConversationTile({
    super.key,
    required this.conversation,
    this.muted = false,
  });

  final Conversation conversation;
  final bool muted;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final backend = ref.watch(backendProvider);
    final me = backend.me!;
    final title = conversation.displayTitle ?? 'Chat';
    final last = backend.lastMessageOf(conversation.id);
    final unread = backend.unreadCount(conversation.id);
    final myLang = me.languageCode;
    final isGroup = conversation.isGroup;

    String? senderName;
    if (isGroup && last != null && last.senderId != me.id) {
      senderName = backend.contactById(last.senderId)?.name.split(' ').first;
    }

    // Preview mirrors bubble logic: translated when ready, original otherwise.
    String preview;
    if (last == null || last.deleted) {
      preview = 'Say hello 👋';
    } else if (last.kind == MessageKind.voice) {
      final t = last.translations[myLang];
      preview =
          t?.text ??
          last.voice?.translatedTranscripts[myLang] ??
          '🎙 Voice note';
    } else if (last.kind == MessageKind.poll) {
      preview = '📊 ${last.poll?.question ?? 'Poll'}';
    } else {
      final t = last.translations[myLang];
      final outgoing = last.senderId == me.id;
      preview =
          outgoing || (t?.status == TranslationStatus.completed)
              ? (t?.text ?? last.text ?? '')
              : (last.text ?? '');
    }

    // Translation state indicator for the latest incoming message.
    final incoming = last != null && last.senderId != me.id;
    final t = last == null ? null : last.translations[myLang];
    Widget? translationGlyph;
    if (incoming && !last.deleted) {
      if (t?.status == TranslationStatus.translating ||
          t?.status == TranslationStatus.queued) {
        translationGlyph = const SizedBox(
          width: 12,
          height: 12,
          child: CircularProgressIndicator(strokeWidth: 1.6),
        );
      } else if (t?.status == TranslationStatus.unavailable) {
        translationGlyph = const Icon(
          Icons.info_outline_rounded,
          size: 13,
          color: Palette.warning,
        );
      } else if (t?.status == TranslationStatus.completed) {
        translationGlyph = const Icon(
          Icons.translate_rounded,
          size: 13,
          color: Palette.cyan,
        );
      }
    }

    final avatarUser = isGroup ? null : conversation.other;
    final dark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color:
          unread > 0
              ? (dark ? Palette.darkCard.withValues(alpha: .55) : null)
              : Colors.transparent,
      borderRadius: BorderRadius.circular(Layout.rLg),
      child: InkWell(
        onTap: () => context.push('/chat/${conversation.id}'),
        borderRadius: BorderRadius.circular(Layout.rLg),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          child: Row(
            children: [
              if (avatarUser != null)
                UserAvatar(
                  name: avatarUser.name,
                  gradient: avatarUser.gradient,
                  userId: avatarUser.id,
                  imageUrl: avatarUser.avatarUrl,
                  size: Layout.avatarMd,
                  online: avatarUser.presence.online,
                  heroTag: 'avatar-${avatarUser.id}',
                )
              else
                Container(
                  width: Layout.avatarMd,
                  height: Layout.avatarMd,
                  decoration: BoxDecoration(
                    color: Palette.cyanSoft,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.groups_rounded,
                    color: Palette.cyan,
                    size: 24,
                  ),
                ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight:
                                  unread > 0
                                      ? FontWeight.w800
                                      : FontWeight.w700,
                              fontSize: 15.5,
                              color:
                                  dark ? Palette.textPrimary : Palette.lightInk,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (last != null)
                          Text(
                            formatListStamp(last.createdAt, DateTime.now()),
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight:
                                  unread > 0
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                              color:
                                  unread > 0
                                      ? Palette.cyan
                                      : (dark
                                          ? Palette.textMuted
                                          : Palette.lightFaint),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (senderName != null)
                          Padding(
                            padding: const EdgeInsets.only(right: 4),
                            child: Text(
                              '$senderName:',
                              style: const TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                color: Palette.textSecondary,
                              ),
                            ),
                          ),
                        if (last != null && last.senderId == me.id) ...[
                          DeliveryGlyph(state: last.delivery),
                          const SizedBox(width: 4),
                        ] else if (translationGlyph != null) ...[
                          translationGlyph,
                          const SizedBox(width: 5),
                        ],
                        Expanded(
                          child: Text(
                            conversation.isTyping ? 'typing…' : preview,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight:
                                  unread > 0
                                      ? FontWeight.w600
                                      : FontWeight.w400,
                              color:
                                  conversation.isTyping
                                      ? Palette.cyan
                                      : (dark
                                          ? Palette.textSecondary
                                          : Palette.lightMuted),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (conversation.isTyping)
                          const TypingDots(size: 6)
                        else if (unread > 0)
                          UnreadBadge(unread)
                        else if (muted)
                          Icon(
                            Icons.notifications_off_rounded,
                            size: 15,
                            color:
                                dark ? Palette.textMuted : Palette.lightFaint,
                          ),
                      ],
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

/// Delivery tick shared with the chat screen.
class DeliveryGlyph extends StatelessWidget {
  const DeliveryGlyph({super.key, required this.state, this.color});

  final MessageDelivery state;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? Palette.cyan;
    return switch (state) {
      MessageDelivery.sending || MessageDelivery.sent => Icon(
        Icons.check_rounded,
        size: 14,
        color: c.withValues(alpha: .7),
      ),
      MessageDelivery.delivered ||
      MessageDelivery.read ||
      MessageDelivery.failed => Icon(
        Icons.done_all_rounded,
        size: 14,
        color:
            state == MessageDelivery.read
                ? Palette.cyan
                : state == MessageDelivery.failed
                ? Palette.danger
                : c,
      ),
    };
  }
}
