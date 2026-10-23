import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/utils.dart' show App;
import '../../core/theme/palette.dart';
import '../../data/backend_base.dart';
import '../../providers.dart';
import '../../data/models/voice_catalog.dart';
import '../../shared/widgets/kit_scaffold.dart';
import '../../shared/widgets/sheets.dart';
import '../../shared/widgets/ui_kit.dart';

/// Settings tab — Chatbox kit: dark header, white sheet with an avatar
/// header row (opens Profile), nested list rows with pale-teal icons.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final backend = ref.watch(backendProvider);
    final me = backend.me;
    if (me == null) return const SizedBox.shrink();
    final lang = LanguageRegistry.of(me.languageCode);

    final rows = <_RowSpec>[
      _RowSpec(
        icon: Icons.mic_rounded,
        title: 'Speech & Voice',
        subtitle: 'Preview voice notes in your language',
        onTap: () => context.push('/settings/voice'),
      ),
      _RowSpec(
        icon: Icons.lock_person_rounded,
        title: 'Privacy & Safety',
        subtitle: 'Receipts · last seen · typing preview',
        onTap: () => context.push('/settings/privacy'),
      ),
      _RowSpec(
        icon: Icons.block_rounded,
        title: 'Blocked Users',
        value: '${blockedCount(backend)}',
        onTap: () => context.push('/settings/privacy'),
      ),
      _RowSpec(
        icon: Icons.list_alt_rounded,
        title: 'Chats',
        subtitle: 'Theme · backups · history (demo)',
        onTap: () => infoToast(context, 'Chat tools are demo-only'),
      ),
      _RowSpec(
        icon: Icons.notifications_none_rounded,
        title: 'Notifications',
        subtitle: 'Muted per-chat from the Home list',
        onTap: () => infoToast(context, 'Manage swipes on Home (demo)'),
      ),
      _RowSpec(
        icon: Icons.help_outline_rounded,
        title: 'Help & Support',
        subtitle: 'Report problems · translate guide',
        onTap: () => infoToast(context, 'Support is demo-only'),
      ),
    ];

    return KitPage(
      title: 'Settings',
      leading: const Icon(Icons.arrow_back_rounded),
      onLeading: () => context.pop(),
      sheetChildren: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 130),
            children: [
              // Profile header row
              InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () => context.push('/settings/profile'),
                child: Row(
                  children: [
                    UserAvatar(
                      name: me.name,
                      gradient: me.gradient,
                      userId: me.id,
                      imageUrl: me.avatarUrl,
                      size: 62,
                      heroTag: 'me-settings-avatar',
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            me.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 16.5,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '@${me.username} · Online',
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: Palette.online,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right_rounded,
                      size: 22,
                      color: Colors.grey,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              const Divider(color: Palette.border),
              // Language row tile
              _TileRow(
                icon: Icons.g_translate_rounded,
                title: 'Messages arrive in',
                value: '${lang.flag}  ${lang.nativeName}',
                onTap: () => context.push('/settings/language'),
              ),
              _TileRow(
                icon: Icons.graphic_eq_rounded,
                title: 'Voice-note language',
                value:
                    '${LanguageRegistry.of(me.speechLanguageCode ?? me.languageCode).flag}  '
                    '${LanguageRegistry.of(me.speechLanguageCode ?? me.languageCode).nativeName}',
                onTap: () => context.push('/settings/language'),
              ),
              _TileRow(
                icon: Icons.record_voice_over_rounded,
                title: 'Speech voice',
                value:
                    VoiceCatalog.voices
                        .where((v) => v.id == me.voiceId)
                        .map((v) => v.name)
                        .firstOrNull ??
                    'Aria',
                onTap: () => context.push('/settings/voice'),
              ),
              const SizedBox(height: 6),
              // Theme picker
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
                child: _ThemePicker(current: backend.themeMode),
              ),
              const SizedBox(height: 6),
              for (final r in rows)
                _TileRow(
                  icon: r.icon,
                  title: r.title,
                  value: r.value,
                  subtitle: r.subtitle,
                  onTap: r.onTap,
                ),
              const SizedBox(height: 12),
              const _TileRow(
                icon: Icons.auto_awesome_rounded,
                title: App.name,
                value: 'v${App.version} · demo',
              ),
              const SizedBox(height: 16),
              GhostButton(
                label: 'Sign out',
                icon: Icons.logout_rounded,
                danger: true,
                onPressed: () async {
                  await backend.signOut();
                  if (context.mounted) context.go('/onboarding');
                },
              ),
              const SizedBox(height: 8),
              Text(
                App.demoNote,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11.5,
                  height: 1.45,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  int blockedCount(UniBackend backend) {
    var n = 0;
    for (final c in backend.contacts) {
      if (backend.isBlocked(c)) n++;
    }
    return n;
  }
}

class _RowSpec {
  const _RowSpec({
    required this.icon,
    required this.title,
    this.subtitle,
    this.value,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final String? value;
  final VoidCallback? onTap;
}

class _TileRow extends StatelessWidget {
  const _TileRow({
    required this.icon,
    required this.title,
    this.subtitle,
    this.value,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final String? value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Palette.chipMint.withValues(alpha: .4),
          borderRadius: BorderRadius.circular(13),
        ),
        child: Icon(icon, size: 20, color: Palette.irisDark),
      ),
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.4),
      ),
      subtitle:
          subtitle == null
              ? null
              : Text(
                subtitle!,
                style: const TextStyle(
                  fontSize: 11.8,
                  color: Palette.textSecondary,
                ),
              ),
      trailing:
          value == null
              ? const Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: Colors.grey,
              )
              : Text(
                value!,
                style: const TextStyle(
                  fontSize: 12.6,
                  fontWeight: FontWeight.w700,
                  color: Palette.textSecondary,
                ),
              ),
    );
  }
}

class _ThemePicker extends ConsumerWidget {
  const _ThemePicker({required this.current});

  final ThemeMode current;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final backend = ref.read(backendProvider);
    return Row(
      children: [
        _pill(
          context,
          backend,
          ThemeMode.system,
          'Auto',
          Icons.brightness_auto_rounded,
        ),
        const SizedBox(width: 8),
        _pill(
          context,
          backend,
          ThemeMode.light,
          'Light',
          Icons.light_mode_rounded,
        ),
        const SizedBox(width: 8),
        _pill(
          context,
          backend,
          ThemeMode.dark,
          'Dark',
          Icons.dark_mode_rounded,
        ),
      ],
    );
  }

  Widget _pill(
    BuildContext context,
    UniBackend backend,
    ThemeMode mode,
    String label,
    IconData icon,
  ) {
    final active = current == mode;
    return Expanded(
      child: Material(
        color:
            active ? Palette.iris.withValues(alpha: .12) : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: () => backend.setThemeMode(mode),
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color:
                    active
                        ? Palette.iris
                        : Theme.of(context).colorScheme.outline,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 16,
                  color:
                      active
                          ? Palette.irisDark
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      label,
                      maxLines: 1,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color:
                            active
                                ? Palette.irisDark
                                : Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                      ),
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
}
