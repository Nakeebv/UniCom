import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers.dart';
import '../../shared/widgets/ui_kit.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  late final TextEditingController _name;
  late final TextEditingController _username;
  late final TextEditingController _about;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final me = ref.read(backendProvider).me!;
    _name = TextEditingController(text: me.name);
    _username = TextEditingController(text: me.username);
    _about = TextEditingController(text: me.about ?? '');
  }

  @override
  void dispose() {
    _name.dispose();
    _username.dispose();
    _about.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    await ref
        .read(backendProvider)
        .updateProfile(
          name: _name.text.trim(),
          username: _username.text.trim().toLowerCase(),
          about: _about.text.trim(),
        );
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Profile updated')));
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(backendProvider).me!;
    return Scaffold(
      appBar: AppBar(title: const Text('Your profile')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 30),
        children: [
          Center(
            child: Hero(
              tag: 'me-avatar',
              child: UserAvatar(
                name: me.name,
                gradient: me.gradient,
                userId: me.id,
                imageUrl: me.avatarUrl,
                size: 96,
                showOnline: false,
              ),
            ),
          ),
          const SizedBox(height: 26),
          UniField(
            controller: _name,
            label: 'Name',
            hint: 'Your name',
            icon: Icons.person_outline_rounded,
          ),
          const SizedBox(height: 14),
          UniField(
            controller: _username,
            label: 'Username',
            hint: 'handle',
            icon: Icons.alternate_email_rounded,
          ),
          const SizedBox(height: 14),
          UniField(
            controller: _about,
            label: 'About',
            hint: 'A line about you',
            icon: Icons.notes_rounded,
          ),
          const SizedBox(height: 28),
          PrimaryButton(
            label: 'Save changes',
            loading: _saving,
            onPressed: _save,
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              'Demo profile · changes persist on this device',
              style: TextStyle(
                fontSize: 11.5,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
