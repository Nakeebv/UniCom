import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/palette.dart';
import '../../data/demo/mock_backend.dart';
import '../../data/models/language.dart';
import '../../data/models/user.dart';
import '../../providers.dart';
import '../../shared/widgets/sheets.dart';
import '../../shared/widgets/ui_kit.dart';

/// Contact profile — Chatbox kit: dark hero with round avatar + username,
/// four action circles (video call / voice call / search / options/more),
/// then white sheet rows with details and About.
class ProfileViewScreen extends ConsumerWidget {
  const ProfileViewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = GoRouterState.of(context).pathParameters['id'] ?? 'usr_amara';
    final backend = ref.watch(backendProvider);
    final user = backend.contactById(id) ?? backend.contacts.first;
    final lang = LanguageRegistry.of(user.languageCode);
    final blocked = backend.isBlocked(user);

    return Scaffold(
      body: Column(
        children: [
          // Dark hero
          Container(
            decoration: const BoxDecoration(
              color: Palette.darkHeader,
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
            ),
            child: SafeArea(
              bottom: false,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 6,
                    ),
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: () => context.pop(),
                          child: Container(
                            width: 46,
                            height: 46,
                            decoration: const BoxDecoration(
                              color: Colors.white24,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.arrow_back_rounded,
                              color: Colors.white,
                              size: 22,
                            ),
                          ),
                        ),
                        const Expanded(
                          child: Text(
                            'Profile',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 17,
                            ),
                          ),
                        ),
                        const SizedBox(width: 46),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Hero(
                    tag: 'avatar-${user.id}',
                    child: UserAvatar(
                      name: user.name,
                      gradient: user.gradient,
                      userId: user.id,
                      imageUrl: user.avatarUrl,
                      size: 116,
                      online: user.presence.online,
                      showOnline: false,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    user.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -.2,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    '@${user.username} · ${user.presence.online ? "Online" : "Last seen recently"}',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: .75),
                      fontWeight: FontWeight.w700,
                      fontSize: 13.5,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    spacing: 40,
                    children: [
                      _HeroAction(
                        icon: Icons.videocam_rounded,
                        background: Palette.danger,
                        onTap: () => context.push('/call/live/${user.id}'),
                      ),
                      _HeroAction(
                        icon: Icons.phone_rounded,
                        background: Palette.iris,
                        onTap: () => context.push('/call/incoming/${user.id}'),
                      ),
                      _HeroAction(
                        icon: Icons.search_rounded,
                        background: Colors.white38,
                        onTap:
                            () => infoToast(context, 'In-chat search (demo)'),
                      ),
                      _HeroAction(
                        icon: Icons.more_horiz_rounded,
                        background: Colors.white24,
                        onTap: () => _optionsSheet(context, ref, user, blocked),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
          // Details sheet
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 40),
              children: [
                _DetailTile(
                  icon: Icons.mic_rounded,
                  label: '${lang.flag} Speaks ${lang.nativeName}',
                  value:
                      'translated into your ${meLanguageLabel(backend)} alongside the original',
                ),
                if (user.about != null)
                  _DetailTile(
                    icon: Icons.info_outline_rounded,
                    label: 'About',
                    value: user.about!,
                  ),
                _DetailTile(
                  icon: Icons.language_rounded,
                  label: 'Language',
                  value: '${lang.nativeName} (${lang.name})',
                  trailing: lang.note,
                ),
                _DetailTile(
                  icon: Icons.share_rounded,
                  label: 'Media, links & docs',
                  value: 'Shared in this chat (demo)',
                ),
                const SizedBox(height: 18),
                Divider(color: Palette.border),
                blocked
                    ? _DangerLink(
                      label: 'Unblock ${user.name.split(' ').first}',
                      onTap: () {
                        backend.unblockUser(user.id);
                        infoToast(context, 'Unblocked');
                      },
                    )
                    : _DangerLink(
                      label: 'Block ${user.name.split(' ').first}',
                      onTap: () async {
                        final ok = await confirmDialog(
                          context,
                          title: 'Block ${user.name.split(' ').first}?',
                          message:
                              'They will no longer be able to message you on UniCom.',
                          confirmLabel: 'Block',
                          danger: true,
                        );
                        if (ok) {
                          await backend.blockUser(user.id);
                          if (context.mounted) context.pop();
                        }
                      },
                    ),
                _DangerLink(
                  label: 'Report ${user.name.split(' ').first}',
                  dangerOnly: true,
                  onTap:
                      () => infoToast(
                        context,
                        'Report sent. Moderators will review (demo).',
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String meLanguageLabel(MockBackend backend) =>
      LanguageRegistry.of(backend.me?.languageCode ?? 'en').nativeName;

  void _optionsSheet(
    BuildContext context,
    WidgetRef ref,
    UserProfile user,
    bool blocked,
  ) {
    showUniSheet(
      context: context,
      builder:
          (sheetContext) => SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 4, 10, 14),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _SheetActionLink(
                    icon: Icons.person_add_alt_rounded,
                    label: 'Add to favorites',
                    onTap: () {
                      Navigator.pop(sheetContext);
                      infoToast(context, 'Favorites are demo-only');
                    },
                  ),
                  _SheetActionLink(
                    icon: Icons.archive_outlined,
                    label: 'Archive chat',
                    onTap: () {
                      Navigator.pop(sheetContext);
                      infoToast(context, 'Archiving is demo-only');
                    },
                  ),
                ],
              ),
            ),
          ),
    );
  }
}

class _HeroAction extends StatelessWidget {
  const _HeroAction({
    required this.icon,
    required this.background,
    required this.onTap,
  });

  final IconData icon;
  final Color background;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(color: background, shape: BoxShape.circle),
        child: Icon(icon, color: Colors.white, size: 22),
      ),
    );
  }
}

class _DetailTile extends StatelessWidget {
  const _DetailTile({
    required this.icon,
    required this.label,
    required this.value,
    this.trailing,
  });

  final IconData icon;
  final String label;
  final String value;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Palette.chipMint.withValues(alpha: .45),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, size: 19, color: Palette.irisDark),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1.4,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                if (trailing != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Text(
                      trailing!,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: Palette.textMuted,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DangerLink extends StatelessWidget {
  const _DangerLink({
    required this.label,
    required this.onTap,
    this.dangerOnly = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool dangerOnly;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      contentPadding: EdgeInsets.zero,
      title: Text(
        label,
        style: const TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 14.5,
          color: Palette.danger,
        ),
      ),
    );
  }
}

class _SheetActionLink extends StatelessWidget {
  const _SheetActionLink({required this.icon, required this.label, this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      leading: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: Palette.chipMint.withValues(alpha: .5),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, size: 19, color: Palette.irisDark),
      ),
      title: Text(
        label,
        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
      ),
    );
  }
}
