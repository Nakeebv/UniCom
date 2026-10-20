import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/palette.dart';
import '../../shared/widgets/ui_kit.dart';
import '../../providers.dart';

/// Kit signup: teal labels, underline fields, confirm password,
/// inline error state, disabled→enabled pill.
class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _name = TextEditingController();
  final _username = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _name.dispose();
    _username.dispose();
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  String? get _emailError {
    if (_email.text.isEmpty) return null;
    if (!RegExp(r'.+@.+\..+').hasMatch(_email.text)) {
      return 'Invalid email address';
    }
    return null;
  }

  bool get _valid {
    final wantsUsername = _username.text.trim().length >= 3;
    return _name.text.trim().length >= 2 &&
        wantsUsername &&
        RegExp(r'.+@.+\..+').hasMatch(_email.text) &&
        _password.text.length >= 6 &&
        _confirm.text == _password.text;
  }

  Future<void> _submit() async {
    setState(() => _loading = true);
    await ref
        .read(backendProvider)
        .register(
          name: _name.text.trim(),
          username: _username.text.trim().toLowerCase(),
        );
    if (!mounted) return;
    context.go('/auth/verify');
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final emailError = _emailError;

    InputDecoration underline({required String label, String? error}) =>
        InputDecoration(
          filled: false,
          contentPadding: const EdgeInsets.only(top: 8, bottom: 12),
          border: InputBorder.none,
          enabledBorder: UnderlineInputBorder(
            borderSide: BorderSide(
              color: error != null ? Palette.danger : Palette.border,
            ),
          ),
          focusedBorder: const UnderlineInputBorder(
            borderSide: BorderSide(color: Palette.iris),
          ),
          errorBorder: const UnderlineInputBorder(
            borderSide: BorderSide(color: Palette.danger),
          ),
          errorStyle: const TextStyle(
            color: Palette.danger,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
          labelText: label,
          labelStyle: const TextStyle(
            color: Palette.iris,
            fontSize: 14.5,
            fontWeight: FontWeight.w600,
          ),
        );

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        foregroundColor: scheme.onSurface,
      ),
      body: SafeArea(
        child: MaxWidthBody(
          padding: EdgeInsets.zero,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(26, 8, 26, 30),
            children: [
              const SizedBox(height: 10),
              Center(
                child: Text.rich(
                  TextSpan(
                    children: [
                      const TextSpan(text: 'Sign up with '),
                      TextSpan(
                        text: 'Email',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: scheme.onSurface,
                          decoration: TextDecoration.underline,
                          decorationColor: Palette.teal03,
                          decorationThickness: 3,
                        ),
                      ),
                    ],
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: scheme.onSurface,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Get chatting today — every conversation arrives in your own language.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.5,
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 30),
              TextField(
                controller: _name,
                onChanged: (_) => setState(() {}),
                decoration: underline(label: 'Your name'),
              ),
              const SizedBox(height: 22),
              TextField(
                controller: _username,
                onChanged: (_) => setState(() {}),
                decoration: underline(label: 'Username (@handle)'),
              ),
              const SizedBox(height: 22),
              TextField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                onChanged: (_) => setState(() {}),
                decoration: underline(label: 'Your email', error: emailError),
              ),
              if (emailError != null)
                Align(
                  alignment: Alignment.centerRight,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      emailError,
                      style: const TextStyle(
                        color: Palette.danger,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 22),
              TextField(
                controller: _password,
                obscureText: true,
                onChanged: (_) => setState(() {}),
                decoration: underline(label: 'Password'),
              ),
              const SizedBox(height: 22),
              TextField(
                controller: _confirm,
                obscureText: true,
                onChanged: (_) => setState(() {}),
                decoration: underline(label: 'Confirm Password').copyWith(
                  errorText:
                      _confirm.text.isNotEmpty &&
                              _confirm.text != _password.text
                          ? 'Passwords don\'t match'
                          : null,
                ),
              ),
              const SizedBox(height: 46),
              SizedBox(
                height: 56,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: _valid ? Palette.cyan : Palette.darkCard2,
                    disabledBackgroundColor: Palette.darkCard2,
                    foregroundColor:
                        _valid ? Colors.white : scheme.onSurfaceVariant,
                    disabledForegroundColor: scheme.onSurfaceVariant,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  onPressed: _valid && !_loading ? _submit : null,
                  child:
                      _loading
                          ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.2,
                              valueColor: AlwaysStoppedAnimation(Colors.white),
                            ),
                          )
                          : const Text('Create an account'),
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: Text.rich(
                  TextSpan(
                    style: TextStyle(
                      fontSize: 13.5,
                      color: scheme.onSurfaceVariant,
                    ),
                    children: [
                      const TextSpan(text: 'Already have an account? '),
                      WidgetSpan(
                        alignment: PlaceholderAlignment.middle,
                        child: GestureDetector(
                          onTap: () => context.go('/auth/login'),
                          child: const Text(
                            'Log in',
                            style: TextStyle(
                              color: Palette.iris,
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
