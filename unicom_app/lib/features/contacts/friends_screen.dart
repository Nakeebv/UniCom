import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/palette.dart';
import '../../data/demo/mock_backend.dart';
import '../../data/models/language.dart';
import '../../data/models/user.dart';
import '../../providers.dart';
import '../../shared/widgets/kit_scaffold.dart';
import '../../shared/widgets/sheets.dart';
import '../../shared/widgets/ui_kit.dart';

/// Contacts tab — Chatbox kit: dark header ("Contacts", "+" to create a
/// group), a white sheet with quick actions (New Group / New Contact /
/// New Community) then the alphabetical contact list.
class FriendsScreen extends ConsumerStatefulWidget {
  const FriendsScreen({super.key});

  @override
  ConsumerState<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends ConsumerState<FriendsScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final backend = ref.watch(backendProvider);
    final people =
        backend.contacts
            .where(
              (p) =>
                  _query.isEmpty ||
                  p.name.toLowerCase().contains(_query) ||
                  p.username.contains(_query),
            )
            .toList()
          ..sort((a, b) => a.name.compareTo(b.name));

    return KitPage(
      title: 'Contacts',
      leading: const Icon(Icons.search_rounded),
      onLeading: () {
        showUniSheet(
          context: context,
          builder:
              (sheetContext) => Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SheetHandle(),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(22, 4, 22, 18),
                    child: TextField(
                      autofocus: true,
                      onChanged:
                          (v) => setState(() => _query = v.toLowerCase()),
                      decoration: const InputDecoration(
                        hintText: 'Search contacts…',
                        prefixIcon: Icon(Icons.search_rounded, size: 20),
                      ),
                    ),
                  ),
                ],
              ),
        );
      },
      trailing: Padding(
        padding: const EdgeInsets.only(right: 12),
        child: GestureDetector(
          onTap: () => context.push('/group/new'),
          child: Container(
            width: 42,
            height: 42,
            decoration: const BoxDecoration(
              color: Colors.white24,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.person_add_alt_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
        ),
      ),
      sheetChildren: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 130),
            children: [
              _quickActions(context),
              const SizedBox(height: 10),
              Text(
                'Contacts on UniCom • ${people.length}',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w900,
                  letterSpacing: .7,
                  color: Palette.textSecondary,
                ),
              ),
              const SizedBox(height: 6),
              for (final p in people) _PersonTile(person: p, backend: backend),
              const SizedBox(height: 8),
              _InviteTile(
                onTap:
                    () => infoToast(
                      context,
                      'Invite links are disabled in the demo',
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _quickActions(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          Expanded(
            child: _QuickAction(
              icon: Icons.group_add_rounded,
              color: Palette.iris,
              label: 'New Group',
              onTap: () => context.push('/group/new'),
            ),
          ),
          Expanded(
            child: _QuickAction(
              icon: Icons.person_add_rounded,
              color: const Color(0xFF9B51E0),
              label: 'New Contact',
              onTap:
                  () => infoToast(
                    context,
                    'Adding contacts is disabled in the demo',
                  ),
            ),
          ),
          Expanded(
            child: _QuickAction(
              icon: Icons.diversity_3_rounded,
              color: const Color(0xFF2F80ED),
              label: 'Team Align',
              onTap: () {
                final backend = ref.read(backendProvider);
                final conv = backend.conversations.firstWhere(
                  (c) => c.id == 'conv_team_align',
                );
                context.push('/chat/${conv.id}');
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
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
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(17),
              ),
              child: Icon(icon, color: Colors.white, size: 23),
            ),
            const SizedBox(height: 7),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}

class _PersonTile extends ConsumerWidget {
  const _PersonTile({required this.person, required this.backend});

  final UserProfile person;
  final MockBackend backend;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = LanguageRegistry.of(person.languageCode);
    final blocked = backend.isBlocked(person);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: InkWell(
        onTap:
            blocked
                ? null
                : () {
                  final conv = backend.openWith(person);
                  context.push('/chat/${conv.id}');
                },
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          child: Row(
            children: [
              UserAvatar(
                name: person.name,
                gradient: person.gradient,
                userId: person.id,
                imageUrl: person.avatarUrl,
                size: 54,
                online: person.presence.online,
                heroTag: 'avatar-${person.id}',
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      person.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      person.previewVisible
                          ? '@${person.username} · ${lang.flag} ${lang.nativeName}'
                          : '@${person.username}',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: Palette.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => context.push('/profile/view/${person.id}'),
                icon: const Icon(Icons.chevron_right_rounded, size: 22),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InviteTile extends StatelessWidget {
  const _InviteTile({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        child: Row(
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: Palette.chipMint,
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(
                Icons.share_rounded,
                color: Palette.chipMintInk,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Invite a friend',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                  SizedBox(height: 3),
                  Text(
                    'Bring someone to UniCom — they pick their language once',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: Palette.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
