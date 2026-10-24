import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
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
  bool _uploadingPhoto = false;
  Uint8List? _pendingPhoto;

  @override
  void initState() {
    super.initState();
    final me = ref.read(backendProvider).me!;
    _name = TextEditingController(text: me.name);
    _username = TextEditingController(text: me.username);
    _about = TextEditingController(text: me.about ?? '');
  }

  Future<void> _pickPhoto() async {
    final backend = ref.read(backendProvider);
    if (backend.asRemote == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile photos need live mode (server)')),
      );
      return;
    }
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder:
          (sheet) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.photo_library_outlined),
                  title: const Text('Choose from gallery'),
                  onTap: () => Navigator.pop(sheet, 'gallery'),
                ),
                ListTile(
                  leading: const Icon(Icons.photo_camera_outlined),
                  title: const Text('Take a photo'),
                  onTap: () => Navigator.pop(sheet, 'camera'),
                ),
                if (ref.read(backendProvider).me?.avatarUrl != null)
                  ListTile(
                    leading: const Icon(Icons.delete_outline_rounded),
                    title: const Text('Remove photo'),
                    onTap: () => Navigator.pop(sheet, 'remove'),
                  ),
              ],
            ),
          ),
    );
    if (choice == null || !mounted) return;

    if (choice == 'remove') {
      setState(() => _uploadingPhoto = true);
      try {
        await backend.removeAvatar();
        if (!mounted) return;
        setState(() {
          _pendingPhoto = null;
          _uploadingPhoto = false;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Photo removed')));
      } catch (e) {
        if (!mounted) return;
        setState(() => _uploadingPhoto = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
      return;
    }

    final picker = ImagePicker();
    XFile? file;
    try {
      file = await picker.pickImage(
        source: choice == 'camera' ? ImageSource.camera : ImageSource.gallery,
        maxWidth: 720,
        maxHeight: 720,
        imageQuality: 85,
        preferredCameraDevice: CameraDevice.front,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
      return;
    }
    if (file == null || !mounted) return;

    final bytes = await file.readAsBytes();
    setState(() {
      _pendingPhoto = bytes;
      _uploadingPhoto = true;
    });
    try {
      final mime =
          file.mimeType ??
          (file.path.toLowerCase().endsWith('.png')
              ? 'image/png'
              : 'image/jpeg');
      await backend.updateAvatar(bytes: bytes, mimeType: mime);
      if (!mounted) return;
      setState(() {
        _pendingPhoto = null;
        _uploadingPhoto = false;
      });
      await ref.read(backendProvider).load();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Profile photo updated')));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _pendingPhoto = null;
        _uploadingPhoto = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
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
            child: GestureDetector(
              onTap: _uploadingPhoto ? null : _pickPhoto,
              child: Hero(
                tag: 'me-avatar',
                child: Stack(
                  children: [
                    (_pendingPhoto != null)
                        ? CircleAvatar(
                          radius: 48,
                          backgroundImage: MemoryImage(_pendingPhoto!),
                        )
                        : UserAvatar(
                          name: me.name,
                          gradient: me.gradient,
                          userId: me.id,
                          imageUrl: me.avatarUrl,
                          size: 96,
                          showOnline: false,
                        ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Theme.of(context).scaffoldBackgroundColor,
                            width: 2,
                          ),
                        ),
                        child: Icon(
                          Icons.camera_alt_rounded,
                          size: 15,
                          color: Theme.of(context).colorScheme.onPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
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
