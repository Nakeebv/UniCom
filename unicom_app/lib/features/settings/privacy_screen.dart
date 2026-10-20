import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers.dart';
import '../../shared/widgets/ui_kit.dart';
import '../../core/theme/palette.dart';

class PrivacyScreen extends ConsumerWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final backend = ref.watch(backendProvider);
    final me = backend.me;
    if (me == null) return const SizedBox.shrink();

    final blocked = backend.contacts.where(backend.isBlocked).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Privacy & safety')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
        children: [
          const SectionHeader('Who can see'),
          _card(context, [
            _switch(
              context,
              icon: Icons.done_all_rounded,
              title: 'Read receipts',
              subtitle: 'Show others when you have read messages',
              value: me.readReceipts,
              onChanged: (v) => backend.setPrivacyFlag(readReceipts: v),
            ),
            _divider(),
            _switch(
              context,
              icon: Icons.schedule_rounded,
              title: 'Last seen',
              subtitle: 'Show when you were last online',
              value: me.lastSeenVisible,
              onChanged: (v) => backend.setPrivacyFlag(lastSeenVisible: v),
            ),
            _divider(),
            _switch(
              context,
              icon: Icons.keyboard_rounded,
              title: 'Typing indicator',
              value: me.typingVisible,
              onChanged: (v) => backend.setPrivacyFlag(typingVisible: v),
            ),
            _divider(),
            _switch(
              context,
              icon: Icons.notifications_rounded,
              title: 'Message previews',
              subtitle: 'Show message text in notifications',
              value: me.previewVisible,
              onChanged: (v) => backend.setPrivacyFlag(previewVisible: v),
            ),
          ]),
          const SizedBox(height: 16),
          const SectionHeader('Privacy note'),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Theme.of(
                  context,
                ).colorScheme.outline.withValues(alpha: .6),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.info_outline_rounded,
                  size: 19,
                  color: Palette.iris,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'UniCom translates on the server, so message text and '
                    'voice audio are processed by our translation and speech '
                    'providers. This is not end-to-end encryption — the '
                    'privacy model is disclosed before you decide.',
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.55,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SectionHeader('Blocked users'),
          if (blocked.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 14),
              child: Text(
                'You have not blocked anyone.',
                style: TextStyle(fontSize: 13),
              ),
            )
          else
            ...blocked.map(
              (u) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Theme.of(
                      context,
                    ).colorScheme.outline.withValues(alpha: .6),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.block_rounded,
                      size: 18,
                      color: Theme.of(context).colorScheme.error,
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Text(u.name)),
                    TextButton(
                      onPressed: () => backend.unblockUser(u.id),
                      child: const Text('Unblock'),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _card(BuildContext context, List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: .6),
        ),
      ),
      child: Column(children: children),
    );
  }

  Widget _divider() => const Padding(
    padding: EdgeInsets.symmetric(horizontal: 16),
    child: Divider(height: .7),
  );

  Widget _switch(
    BuildContext context, {
    required IconData icon,
    required String title,
    String? subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile(
      value: value,
      onChanged: onChanged,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      secondary: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: Palette.iris.withValues(alpha: .09),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, size: 19, color: Palette.irisDark),
      ),
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
      ),
      subtitle:
          subtitle == null
              ? null
              : Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
    );
  }
}
