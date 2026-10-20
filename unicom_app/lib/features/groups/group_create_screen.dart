import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/palette.dart';
import '../../data/models/user.dart';
import '../../providers.dart';
import '../../shared/widgets/ui_kit.dart';

/// "Create Group" — name field, member picker with counters, teal Create
/// pill. Opens the fresh conversation on success.
class GroupCreateScreen extends ConsumerStatefulWidget {
  const GroupCreateScreen({super.key});

  @override
  ConsumerState<GroupCreateScreen> createState() => _GroupCreateScreenState();
}

class _GroupCreateScreenState extends ConsumerState<GroupCreateScreen> {
  final _title = TextEditingController();
  final Set<String> _selected = {};

  static const _groupColors = [
    Palette.iris,
    Color(0xFF9B51E0),
    Color(0xFF2F80ED),
    Color(0xFFF2994A),
    Color(0xFF2AA95C),
  ];

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  void _create() {
    if (_title.text.trim().isEmpty || _selected.length < 2) return;
    final conv = ref
        .read(backendProvider)
        .createGroup(_title.text, _selected.toList());
    context
      ..pop()
      ..push('/chat/${conv.id}');
  }

  @override
  Widget build(BuildContext context) {
    final backend = ref.watch(backendProvider);
    final valid = _title.text.trim().isNotEmpty && _selected.length >= 2;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
        title: const Text(
          'Create Group',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
        ),
      ),
      body: MaxWidthBody(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 6, 24, 40),
          children: [
            Center(
              child: Container(
                width: 84,
                height: 84,
                decoration: BoxDecoration(
                  color: _groupColors[_selected.length % _groupColors.length],
                  borderRadius: BorderRadius.circular(28),
                ),
                child: const Icon(
                  Icons.groups_rounded,
                  color: Colors.white,
                  size: 40,
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Group Title',
              style: TextStyle(
                color: Palette.iris,
                fontWeight: FontWeight.w700,
                fontSize: 13.5,
              ),
            ),
            TextField(
              controller: _title,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                hintText: 'e.g. Team Align',
                border: InputBorder.none,
              ),
            ),
            const Divider(),
            const SizedBox(height: 10),
            Text(
              'Members · ${_selected.length} selected',
              style: TextStyle(
                color: Palette.iris,
                fontWeight: FontWeight.w700,
                fontSize: 13.5,
              ),
            ),
            const SizedBox(height: 6),
            for (final c in backend.contacts)
              _MemberRow(
                person: c,
                selected: _selected.contains(c.id),
                onToggle:
                    () => setState(
                      () =>
                          _selected.contains(c.id)
                              ? _selected.remove(c.id)
                              : _selected.add(c.id),
                    ),
              ),
            const SizedBox(height: 24),
            SizedBox(
              height: 56,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: valid ? Palette.cyan : Palette.darkCard2,
                  foregroundColor:
                      valid ? const Color(0xFF00232B) : Palette.textMuted,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                onPressed: valid ? _create : null,
                child: Text('Create group (${_selected.length + 1})'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MemberRow extends StatelessWidget {
  const _MemberRow({
    required this.person,
    required this.selected,
    required this.onToggle,
  });

  final UserProfile person;
  final bool selected;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onToggle,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      leading: UserAvatar(
        name: person.name,
        gradient: person.gradient,
        userId: person.id,
        imageUrl: person.avatarUrl,
        size: 44,
        online: person.presence.online,
      ),
      title: Text(
        person.name,
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      trailing: Container(
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: selected ? Palette.iris : Colors.transparent,
          border: Border.all(
            color: selected ? Palette.iris : Colors.grey.shade300,
            width: 1.8,
          ),
        ),
        child:
            selected
                ? const Icon(Icons.check_rounded, size: 16, color: Colors.white)
                : null,
      ),
    );
  }
}
