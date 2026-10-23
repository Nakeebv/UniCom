import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/palette.dart';
import '../../core/theme/theme.dart';
import '../../core/utils.dart';
import '../../data/backend_base.dart';
import '../../providers.dart';
import '../../shared/widgets/kit_scaffold.dart';
import '../../shared/widgets/sheets.dart';
import '../../shared/widgets/ui_kit.dart';
import 'widgets/composer.dart';
import 'widgets/message_bubble.dart';

/// A chat thread — Chatbox kit: dark header with avatar + Active-now and
/// phone/video actions, pale translation banner, bubbles, kit composer.
class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final ScrollController _scroll = ScrollController();
  String? _convId;
  UniBackend? _cachedBackend;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final id = GoRouterState.of(context).pathParameters['id'];
    if (id != _convId) {
      _convId = id;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _cachedBackend?.asRemote?.setActiveConversation(id);
        ref.read(backendProvider).markRead(id!);
        _jumpBottom();
      });
    }
  }

  @override
  void dispose() {
    _cachedBackend?.asRemote?.setActiveConversation(null);
    _scroll.dispose();
    super.dispose();
  }

  void _jumpBottom() {
    if (!_scroll.hasClients) {
      Future<void>.delayed(const Duration(milliseconds: 220), _jumpBottom);
      return;
    }
    _scroll.animateTo(
      _scroll.position.maxScrollExtent,
      duration: const Duration(milliseconds: 380),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final backend = ref.watch(backendProvider);
    _cachedBackend = backend;
    final conv = backend.conversationOf(_convId ?? '');
    final me = backend.me;
    if (conv == null || me == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final other = conv.isGroup ? conv.others.first : conv.other;
    final messages = backend.messagesOf(conv.id);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients &&
          _scroll.position.maxScrollExtent - _scroll.offset < 260) {
        _jumpBottom();
      }
    });

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: _appBar(context, backend, conv, other),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: Layout.maxContentWidth + 120,
          ),
          child: Column(
            children: [
              _languageBanner(conv, other, me),
              Expanded(
                child: GestureDetector(
                  onTap: () => FocusScope.of(context).unfocus(),
                  child: ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
                    itemCount: messages.length + (conv.isTyping ? 1 : 0),
                    itemBuilder: (context, i) {
                      if (conv.isTyping && i == messages.length) {
                        return _typingRow();
                      }
                      final m = messages[i];
                      return _row(context, m, conv, backend, me, i);
                    },
                  ),
                ),
              ),
              Composer(
                enabled: conv.isGroup || !backend.isBlocked(other),
                onSendText: (text) {
                  backend.sendMessage(conv.id, text);
                  _jumpBottom();
                },
                onSendVoice: (result) {
                  backend.sendVoiceNote(
                    conv.id,
                    result.duration,
                    result.samples,
                    filePath: result.path,
                    bytes: result.bytes,
                    mimeType: result.mimeType,
                  );
                  _jumpBottom();
                },
                onDemoVoice: (duration) async {
                  final mock = backend.asMock;
                  if (mock == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Demo voice notes are offline-mode only — record with the mic instead',
                        ),
                      ),
                    );
                    return;
                  }
                  mock.sendVoiceNote(
                    conv.id,
                    duration,
                    Message.seededWaveform('demo-${DateTime.now()}'),
                  );
                  _jumpBottom();
                },
                onTyping: () => _cachedBackend?.asRemote?.notifyTyping(),
                onShare: () => _shareSheet(context, conv),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Starts a real call: invite the peer server-side (they get an SSE ring),
  /// then join the room the server allocated.
  Future<void> _startCall(String peerId, {required bool video}) async {
    final remote = ref.read(backendProvider).asRemote;
    if (remote == null) {
      if (mounted) {
        infoToast(context, 'Calling needs live mode (server)');
      }
      return;
    }
    try {
      final invite = await remote.startCall(
        calleeId: peerId,
        callType: video ? 'video' : 'audio',
      );
      final room = invite?['room'] as String?;
      final callId = invite?['call_id'] as String?;
      if (!mounted) return;
      context.push(
        '/call/live/$peerId?room=${Uri.encodeComponent(room ?? '')}'
        '${callId != null ? '&call=$callId' : ''}'
        '${video ? '&video=1' : ''}',
      );
    } catch (e) {
      if (mounted) {
        infoToast(context, e.toString().replaceFirst('Exception: ', ''));
      }
    }
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  Widget _row(
    BuildContext context,
    Message m,
    Conversation conv,
    UniBackend backend,
    UserProfile me,
    int index,
  ) {
    final other = conv.isGroup ? conv.others.first : conv.other;
    final sender = backend.contactById(m.senderId) ?? other;
    final isMine = m.senderId == me.id;
    final prev = index > 0 ? backend.messagesOf(conv.id)[index - 1] : null;
    String? nameLabel;
    var showName = false;
    if (conv.isGroup && !isMine) {
      final prevSameSender = prev != null && prev.senderId == m.senderId;
      showName = !prevSameSender;
      nameLabel = sender.name.split(' ').first;
    }

    return Column(
      children: [
        if (index == 0 ||
            (prev != null && !_sameDay(prev.createdAt, m.createdAt)))
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Capsule(
              label: formatDayLabel(m.createdAt, DateTime.now()),
              fontSize: 11,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            ),
          ),
        MessageBubble(
          message: m,
          viewerId: me.id,
          targetLanguage: me.languageCode,
          otherName: sender.name,
          otherGradient: sender.gradient,
          onRetryTranslation:
              () => _retry(m, LanguageRegistry.of(sender.languageCode).code),
          onLongPress: () => _messageActions(context, m, conv, sender),
          onTapAvatar:
              conv.isGroup
                  ? () => context.push('/profile/view/${sender.id}')
                  : () => context.push('/profile/view/${other.id}'),
          isGroupTail: true,
          onVotePoll:
              m.kind == MessageKind.poll && !isMine
                  ? (i) => backend.votePoll(conv.id, m.id, i)
                  : null,
          senderNameLabel: nameLabel,
          showSenderName: showName,
          otherAvatarUrl: sender.avatarUrl,
        ),
      ],
    );
  }

  void _retry(Message m, String target) {
    final backend = ref.read(backendProvider);
    if (m.kind == MessageKind.voice) {
      backend.retryVoiceSpeech(m.id);
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Retrying translation…')));
      backend.resendTranslation(m.id, target);
    }
  }

  Widget _typingRow() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.fromLTRB(14, 10, 16, 10),
        decoration: BoxDecoration(
          color:
              Theme.of(context).brightness == Brightness.dark
                  ? Palette.darkBubbleIn
                  : Palette.lightBubbleIn,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(6),
            topRight: Radius.circular(16),
            bottomLeft: Radius.circular(16),
            bottomRight: Radius.circular(16),
          ),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            TypingDots(),
            SizedBox(width: 8),
            Text(
              'typing…',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: Palette.iris,
              ),
            ),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _appBar(
    BuildContext context,
    UniBackend backend,
    Conversation conv,
    UserProfile other,
  ) {
    final isGroup = conv.isGroup;
    final title = conv.displayTitle ?? 'Chat';
    final activeOnline = conv.others.where((m) => m.presence.online).length;
    final subtitle =
        isGroup
            ? (conv.isTyping
                ? 'typing…'
                : '${conv.members.length} members · $activeOnline online')
            : (conv.isTyping
                ? 'typing…'
                : other.presence.online
                ? 'Active now'
                : 'last seen recently');

    return AppBar(
      backgroundColor: Palette.darkHeader,
      foregroundColor: Colors.white,
      elevation: 0,
      leadingWidth: 52,
      leading: IconButton(
        onPressed: () => context.pop(),
        icon: const Icon(Icons.arrow_back_rounded),
      ),
      titleSpacing: 0,
      title: InkWell(
        onTap:
            () =>
                conv.isGroup
                    ? _groupSheet(context, conv)
                    : context.push('/profile/view/${other.id}'),
        borderRadius: BorderRadius.circular(14),
        child: Row(
          children: [
            if (isGroup)
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Palette.iris,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.groups_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              )
            else
              UserAvatar(
                name: other.name,
                gradient: other.gradient,
                userId: other.id,
                imageUrl: other.avatarUrl,
                size: 40,
                online: other.presence.online,
                heroTag: 'avatar-${other.id}',
              ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 1),
                  AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 200),
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color:
                          conv.isTyping
                              ? Palette.teal03
                              : Palette.teal03.withValues(
                                alpha: conv.isTyping ? 1 : .9,
                              ),
                    ),
                    child: Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        // Compact, consistent 44px targets; the title uses Expanded so it
        // truncates instead of pushing the actions off-screen.
        _AppBarAction(
          icon: Icons.phone_outlined,
          tooltip: 'Voice call',
          onTap: () => _startCall(other.id, video: false),
        ),
        _AppBarAction(
          icon: Icons.videocam_outlined,
          tooltip: 'Video call',
          onTap: () => _startCall(other.id, video: true),
        ),
        _AppBarAction(
          icon: Icons.more_vert_rounded,
          tooltip: 'Chat options',
          onTap:
              () =>
                  conv.isGroup
                      ? _groupSheet(context, conv)
                      : _peerSheet(context, conv, other),
        ),
        const SizedBox(width: 2),
      ],
    );
  }

  /// The pipeline banner — for groups, lists the languages the members
  /// actually speak.
  Widget _languageBanner(Conversation conv, UserProfile other, UserProfile me) {
    final target = LanguageRegistry.of(me.languageCode);
    final source = LanguageRegistry.of(other.languageCode);
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 8, 14, 2),
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
      decoration: BoxDecoration(
        color: Palette.chipMint.withValues(alpha: .35),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Palette.iris.withValues(alpha: .18)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.translate_rounded,
            size: 15,
            color: Palette.irisDark,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text.rich(
              TextSpan(
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: Palette.irisDark,
                ),
                children: [
                  TextSpan(
                    text: conv.isGroup ? 'Group speaks ' : 'Translate from ',
                  ),
                  TextSpan(
                    text:
                        conv.isGroup
                            ? conv.others
                                .map(
                                  (u) =>
                                      LanguageRegistry.of(
                                        u.languageCode,
                                      ).nativeName,
                                )
                                .toSet()
                                .join(' · ')
                            : source.nativeName,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const TextSpan(text: ' → your '),
                  TextSpan(
                    text: target.nativeName,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  /// Chatbox "Share Content" sheet: Camera · Documents · Create a poll ·
  /// Media · Contact · Location.
  void _shareSheet(BuildContext context, Conversation conv) {
    showUniSheet(
      context: context,
      builder:
          (sheetContext) => SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SheetHandle(),
                  const Text(
                    'Share Content',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _ShareCell(
                          icon: Icons.photo_camera_rounded,
                          color: Palette.info,
                          label: 'Camera',
                          onTap: () {
                            Navigator.pop(sheetContext);
                            infoToast(context, 'Camera opens here (demo)');
                          },
                        ),
                      ),
                      Expanded(
                        child: _ShareCell(
                          icon: Icons.insert_drive_file_rounded,
                          color: const Color(0xFF2F80ED),
                          label: 'Documents',
                          onTap: () {
                            Navigator.pop(sheetContext);
                            infoToast(context, 'Document picker (demo)');
                          },
                        ),
                      ),
                      Expanded(
                        child: _ShareCell(
                          icon: Icons.poll_rounded,
                          color: Palette.danger,
                          label: 'Create a poll',
                          onTap: () {
                            Navigator.pop(sheetContext);
                            context.push('/poll/new/${conv.id}');
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _ShareCell(
                          icon: Icons.perm_media_rounded,
                          color: Palette.success,
                          label: 'Media',
                          onTap: () {
                            Navigator.pop(sheetContext);
                            infoToast(context, 'Media gallery (demo)');
                          },
                        ),
                      ),
                      Expanded(
                        child: _ShareCell(
                          icon: Icons.person_pin_rounded,
                          color: Palette.warning,
                          label: 'Contact',
                          onTap: () {
                            Navigator.pop(sheetContext);
                            infoToast(context, 'Contact sharing (demo)');
                          },
                        ),
                      ),
                      Expanded(
                        child: _ShareCell(
                          icon: Icons.location_on_rounded,
                          color: const Color(0xFF9B51E0),
                          label: 'Location',
                          onTap: () {
                            Navigator.pop(sheetContext);
                            infoToast(context, 'Sharing live location (demo)');
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _SheetRow(
                    icon: Icons.poll_rounded,
                    label: 'Create a poll',
                    onTap: () {
                      Navigator.pop(sheetContext);
                      context.push('/poll/new/${conv.id}');
                    },
                  ),
                ],
              ),
            ),
          ),
    );
  }

  void _messageActions(
    BuildContext context,
    Message m,
    Conversation conv,
    UserProfile sender,
  ) {
    final backend = ref.read(backendProvider);
    showUniSheet(
      context: context,
      builder:
          (sheetContext) => SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 4, 10, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            m.text != null && m.text!.isNotEmpty
                                ? m.text!.take(64)
                                : m.kind == MessageKind.poll
                                ? m.poll?.question ?? 'Poll'
                                : 'Voice note',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(),
                  _SheetRow(
                    icon: Icons.copy_rounded,
                    label: 'Copy text',
                    onTap: () {
                      Navigator.pop(sheetContext);
                      infoToast(context, 'Copied to clipboard');
                    },
                  ),
                  if (m.senderId == backend.me?.id &&
                      m.kind != MessageKind.poll)
                    _SheetRow(
                      icon: Icons.delete_outline_rounded,
                      label: 'Delete for everyone',
                      danger: true,
                      onTap: () async {
                        Navigator.pop(sheetContext);
                        final ok = await confirmDialog(
                          context,
                          title: 'Delete message?',
                          message:
                              'Everyone in this conversation will see that the message was removed.',
                          confirmLabel: 'Delete',
                          danger: true,
                        );
                        if (ok) backend.deleteMessage(m.id);
                      },
                    )
                  else
                    _SheetRow(
                      icon: Icons.flag_outlined,
                      label: 'Report message',
                      danger: true,
                      onTap: () {
                        Navigator.pop(sheetContext);
                        backend.reportMessage(m.id, 'abuse');
                        infoToast(
                          context,
                          'Reported. Our moderators will review it.',
                        );
                      },
                    ),
                ],
              ),
            ),
          ),
    );
  }

  /// Group info sheet: title, members as rows, actions.
  void _groupSheet(BuildContext context, Conversation conv) {
    final backend = ref.read(backendProvider);
    showUniSheet(
      context: context,
      builder:
          (sheetContext) => Padding(
            padding: const EdgeInsets.fromLTRB(22, 4, 22, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 74,
                    height: 74,
                    decoration: BoxDecoration(
                      color: Palette.iris,
                      borderRadius: BorderRadius.circular(26),
                    ),
                    child: const Icon(
                      Icons.groups_rounded,
                      color: Colors.white,
                      size: 36,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Center(
                  child: Text(
                    conv.title ?? 'Group',
                    style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Center(
                  child: Text(
                    '${conv.members.length} members',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color:
                          Theme.of(sheetContext).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Members',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1,
                    color: Theme.of(sheetContext).colorScheme.onSurfaceVariant,
                  ),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  onTap: () {
                    Navigator.pop(sheetContext);
                    context.push('/settings/profile');
                  },
                  leading: CircleAvatar(
                    radius: 18,
                    backgroundColor: Palette.chipMint,
                    child: Text(
                      initialsOf(backend.me!.name),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: Palette.chipMintInk,
                      ),
                    ),
                  ),
                  title: Text(
                    '${backend.me!.name} (you)',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                for (final member in conv.others)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    onTap: () {
                      Navigator.pop(sheetContext);
                      context.push('/profile/view/${member.id}');
                    },
                    leading: UserAvatar(
                      name: member.name,
                      gradient: member.gradient,
                      userId: member.id,
                      imageUrl: member.avatarUrl,
                      size: 36,
                      online: member.presence.online,
                    ),
                    title: Text(
                      member.name,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text(
                      'speaks ${LanguageRegistry.of(member.languageCode).nativeName}',
                      style: const TextStyle(fontSize: 11.5),
                    ),
                  ),
                const Divider(),
                _SheetRow(
                  icon: Icons.notifications_rounded,
                  label: 'Group notifications',
                  onTap: () {
                    Navigator.pop(sheetContext);
                    infoToast(context, 'Enabled (demo)');
                  },
                ),
                _SheetRow(
                  icon: Icons.exit_to_app_rounded,
                  label: 'Leave group',
                  danger: true,
                  onTap: () {
                    Navigator.pop(sheetContext);
                    infoToast(
                      context,
                      'Leaving groups is disabled in the demo',
                    );
                  },
                ),
              ],
            ),
          ),
    );
  }

  void _peerSheet(BuildContext context, Conversation conv, UserProfile other) {
    final backend = ref.read(backendProvider);
    final lang = LanguageRegistry.of(other.languageCode);

    showUniSheet(
      context: context,
      builder:
          (sheetContext) => Padding(
            padding: const EdgeInsets.fromLTRB(22, 6, 22, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Hero(
                  tag: 'avatar-${other.id}',
                  child: UserAvatar(
                    name: other.name,
                    gradient: other.gradient,
                    userId: other.id,
                    imageUrl: other.avatarUrl,
                    size: 84,
                    online: other.presence.online,
                    showOnline: false,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  other.name,
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '@${other.username}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(sheetContext).colorScheme.onSurfaceVariant,
                  ),
                ),
                if (other.about != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    other.about!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.4,
                      color:
                          Theme.of(sheetContext).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: [
                    Capsule(
                      icon: Icons.language_rounded,
                      label: '${lang.flag} ${lang.nativeName}',
                      foreground: Palette.chipMintInk,
                      background: Palette.chipMint,
                    ),
                    const Capsule(
                      icon: Icons.mic_rounded,
                      label: 'Voice notes enabled',
                    ),
                    if (lang.note != null)
                      Capsule(icon: Icons.verified_outlined, label: lang.note!),
                  ],
                ),
                const SizedBox(height: 20),
                const Divider(),
                _SheetRow(
                  icon: Icons.g_translate_rounded,
                  label: 'Translation preferences',
                  onTap: () {
                    Navigator.pop(sheetContext);
                    context.push('/settings/language');
                  },
                ),
                _SheetRow(
                  icon: Icons.record_voice_over_rounded,
                  label: 'Speech & voice settings',
                  onTap: () {
                    Navigator.pop(sheetContext);
                    context.push('/settings/voice');
                  },
                ),
                if (backend.isBlocked(other))
                  _SheetRow(
                    icon: Icons.lock_open_rounded,
                    label: 'Unblock ${other.name.split(' ').first}',
                    onTap: () {
                      backend.unblockUser(other.id);
                      Navigator.pop(sheetContext);
                      infoToast(context, 'Unblocked');
                    },
                  )
                else
                  _SheetRow(
                    icon: Icons.block_outlined,
                    label: 'Block ${other.name.split(' ').first}',
                    danger: true,
                    onTap: () async {
                      Navigator.pop(sheetContext);
                      final ok = await confirmDialog(
                        context,
                        title: 'Block ${other.name.split(' ').first}?',
                        message:
                            'They will no longer be able to message you on UniCom.',
                        confirmLabel: 'Block',
                        danger: true,
                      );
                      if (ok) {
                        await backend.blockUser(other.id);
                        if (context.mounted) context.pop();
                      }
                    },
                  ),
              ],
            ),
          ),
    );
  }
}

class _ShareCell extends StatelessWidget {
  const _ShareCell({
    required this.icon,
    required this.color,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
        child: Column(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: color.withValues(alpha: .14),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(height: 7),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SheetRow extends StatelessWidget {
  const _SheetRow({
    required this.icon,
    required this.label,
    this.onTap,
    this.danger = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      leading: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color:
              danger
                  ? scheme.error.withValues(alpha: .1)
                  : Palette.chipMint.withValues(alpha: .5),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          icon,
          size: 19,
          color: danger ? scheme.error : Palette.irisDark,
        ),
      ),
      title: Text(
        label,
        style: TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 14,
          color: danger ? scheme.error : null,
        ),
      ),
    );
  }
}

/// Fixed-width app-bar action so header actions never overlap the title on
/// narrow screens (44px = accessible touch target).
class _AppBarAction extends StatelessWidget {
  const _AppBarAction({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 44,
      height: 44,
      child: IconButton(
        padding: EdgeInsets.zero,
        tooltip: tooltip,
        onPressed: onTap,
        icon: Icon(icon, size: 22),
      ),
    );
  }
}
