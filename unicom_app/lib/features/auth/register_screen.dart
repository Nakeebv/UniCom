import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/palette.dart';
import '../../providers.dart';
import '../../data/api/uni_session.dart';
import '../../shared/widgets/auth_background.dart';

/// Sign-up: username + email availability (debounced), password strength,
/// dark branded photo background consistent with the welcome page.
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

  Timer? _checkDebounce;
  bool? _usernameAvailable;
  bool? _emailAvailable;
  bool _checking = false;

  @override
  void dispose() {
    _checkDebounce?.cancel();
    _name.dispose();
    _username.dispose();
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  bool get _passwordStrong =>
      _password.text.length >= 8 &&
      RegExp(r'[A-Za-z]').hasMatch(_password.text) &&
      RegExp(r'[0-9]').hasMatch(_password.text);

  bool get _valid {
    final wantsUsername = RegExp(
      r'^[a-z0-9_]{3,24}$',
    ).hasMatch(_username.text.trim());
    return _name.text.trim().length >= 2 &&
        wantsUsername &&
        _usernameAvailable == true &&
        RegExp(r'.+@.+\..+').hasMatch(_email.text) &&
        _emailAvailable == true &&
        _passwordStrong &&
        _confirm.text == _password.text;
  }

  /// Debounced availability probe — mirrors the server's normalization so the
  /// green tick means exactly what the server will accept.
  void _scheduleCheck() {
    _checkDebounce?.cancel();
    _checkDebounce = Timer(const Duration(milliseconds: 450), _runCheck);
  }

  Future<void> _runCheck() async {
    final backend = ref.read(backendProvider);
    final remote = backend.asRemote;
    if (remote == null) {
      // Offline demo mode: no server to ask; treat locally-valid as available.
      setState(() {
        final u = _username.text.trim().toLowerCase();
        _usernameAvailable = RegExp(r'^[a-z0-9_]{3,24}$').hasMatch(u);
        _emailAvailable = RegExp(r'.+@.+\..+').hasMatch(_email.text);
      });
      return;
    }
    final u = _username.text.trim().toLowerCase();
    final e = _email.text.trim().toLowerCase();
    setState(() => _checking = true);
    try {
      final res = await remote.api.checkAvailability(
        username: RegExp(r'^[a-z0-9_]{3,24}$').hasMatch(u) ? u : null,
        email: RegExp(r'.+@.+\..+').hasMatch(e) ? e : null,
      );
      if (!mounted) return;
      setState(() {
        _usernameAvailable = res['username_ok'] as bool?;
        _emailAvailable = res['email_ok'] as bool?;
        _checking = false;
      });
    } on ApiError {
      if (mounted) setState(() => _checking = false);
    } catch (_) {
      if (mounted) setState(() => _checking = false);
    }
  }

  String? get _emailError {
    if (_email.text.isEmpty) return null;
    if (!RegExp(r'.+@.+\..+').hasMatch(_email.text)) {
      return 'Invalid email address';
    }
    return null;
  }

  Future<void> _submit() async {
    setState(() => _loading = true);
    await ref
        .read(backendProvider)
        .register(
          name: _name.text.trim(),
          username: _username.text.trim().toLowerCase(),
          password: _password.text,
          email: _email.text.trim().toLowerCase(),
        );
    if (!mounted) return;
    context.go('/auth/verify');
  }

  InputDecoration underline(String label, {String? error}) => InputDecoration(
    filled: false,
    contentPadding: const EdgeInsets.only(top: 8, bottom: 12),
    border: InputBorder.none,
    enabledBorder: const UnderlineInputBorder(
      borderSide: BorderSide(color: Colors.white24),
    ),
    focusedBorder: const UnderlineInputBorder(
      borderSide: BorderSide(color: Palette.teal03, width: 1.5),
    ),
    errorBorder: const UnderlineInputBorder(
      borderSide: BorderSide(color: Palette.danger),
    ),
    focusedErrorBorder: const UnderlineInputBorder(
      borderSide: BorderSide(color: Palette.danger, width: 1.4),
    ),
    errorText: error,
    labelText: label,
    labelStyle: const TextStyle(
      color: Palette.teal03,
      fontSize: 14.5,
      fontWeight: FontWeight.w600,
    ),
  );

  Widget? _availIcon(bool? v) {
    if (_checking) {
      return const Padding(
        padding: EdgeInsets.all(14),
        child: SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    if (v == null) return null;
    return Icon(
      v ? Icons.check_circle_rounded : Icons.error_outline_rounded,
      color: v ? Palette.success : Palette.danger,
      size: 20,
    );
  }

  Widget _availHint(
    bool? v, {
    required String okText,
    required String badText,
  }) {
    if (v == null) return const SizedBox.shrink();
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(top: 4, left: 6),
        child: Text(
          v ? okText : badText,
          style: TextStyle(
            color: v ? Palette.success : Palette.danger,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final emailError = _emailError;

    return Scaffold(
      backgroundColor: const Color(0xFF030A0B),
      resizeToAvoidBottomInset: true,
      body: AuthBackground(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(26, 20, 26, 30),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          children: [
            const SizedBox(height: 10),
            const Center(
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(text: 'Sign up with '),
                    TextSpan(
                      text: 'Email',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        decoration: TextDecoration.underline,
                        decorationColor: Palette.teal03,
                        decorationThickness: 3,
                      ),
                    ),
                  ],
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Get chatting today — every conversation arrives in your own '
              'language.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                height: 1.5,
                color: Colors.white.withValues(alpha: .75),
              ),
            ),
            const SizedBox(height: 30),
            TextField(
              controller: _name,
              onChanged: (_) => setState(() {}),
              style: const TextStyle(color: Colors.white),
              cursorColor: Palette.teal03,
              decoration: underline('Your name'),
            ),
            const SizedBox(height: 22),
            TextField(
              controller: _username,
              onChanged: (_) {
                setState(() => _usernameAvailable = null);
                _scheduleCheck();
              },
              style: const TextStyle(color: Colors.white),
              cursorColor: Palette.teal03,
              decoration: underline(
                'Username (@handle)',
              ).copyWith(suffixIcon: _availIcon(_usernameAvailable)),
            ),
            _availHint(
              _usernameAvailable,
              okText: 'Username is available',
              badText: 'That username is taken',
            ),
            const SizedBox(height: 22),
            TextField(
              controller: _email,
              style: const TextStyle(color: Colors.white),
              cursorColor: Palette.teal03,
              keyboardType: TextInputType.emailAddress,
              onChanged: (_) {
                setState(() => _emailAvailable = null);
                _scheduleCheck();
              },
              decoration: underline(
                'Your email',
                error: emailError,
              ).copyWith(suffixIcon: _availIcon(_emailAvailable)),
            ),
            _availHint(
              _emailAvailable,
              okText: 'Email is available',
              badText: 'An account with this email already exists',
            ),
            const SizedBox(height: 22),
            TextField(
              controller: _password,
              obscureText: true,
              onChanged: (_) => setState(() {}),
              style: const TextStyle(color: Colors.white),
              cursorColor: Palette.teal03,
              decoration: underline('Password'),
            ),
            if (_password.text.isNotEmpty && !_passwordStrong)
              const Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: EdgeInsets.only(top: 4, left: 6),
                  child: Text(
                    'At least 8 characters with a letter and a number',
                    style: TextStyle(
                      color: Palette.warning,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 22),
            TextField(
              controller: _confirm,
              obscureText: true,
              onChanged: (_) => setState(() {}),
              style: const TextStyle(color: Colors.white),
              cursorColor: Palette.teal03,
              decoration: underline('Confirm Password').copyWith(
                errorText:
                    _confirm.text.isNotEmpty && _confirm.text != _password.text
                        ? "Passwords don't match"
                        : null,
              ),
            ),
            const SizedBox(height: 46),
            SizedBox(
              height: 56,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor:
                      _valid
                          ? Palette.teal
                          : Colors.white.withValues(alpha: .16),
                  foregroundColor:
                      _valid ? const Color(0xFF06211F) : Colors.white60,
                  disabledForegroundColor: Colors.white.withValues(alpha: .6),
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
                    color: Colors.white.withValues(alpha: .72),
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
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 13.5,
                            decoration: TextDecoration.underline,
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
    );
  }
}
