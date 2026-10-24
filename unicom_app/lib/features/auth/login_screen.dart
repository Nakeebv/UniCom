import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/palette.dart';
import '../../providers.dart';
import '../../shared/widgets/auth_background.dart';
import '../../shared/widgets/logo.dart';

/// Log in — username + password, on the shared branded photo background.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;
  bool _obscure = true;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  bool get _valid =>
      _email.text.trim().length >= 3 && _password.text.isNotEmpty;

  Future<void> _submit() async {
    setState(() => _loading = true);
    final backend = ref.read(backendProvider);
    try {
      await backend
          .signIn(_email.text.trim(), password: _password.text)
          .timeout(const Duration(seconds: 20));
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
      return;
    }
    if (!mounted) return;
    if (backend.onboarded) {
      backend.ensureSeeded();
      context.go('/chats');
    } else {
      context.go('/auth/language');
    }
  }

  /// Dev convenience: one-tap sign-in as a seeded demo account. Field values
  /// are filled in so the same path as a normal login runs (no auth bypass).
  Future<void> _quickSignIn(String username) async {
    setState(() {
      _email.text = username;
      _password.text = 'pass1234';
    });
    await _submit();
  }

  InputDecoration underline(String label) => InputDecoration(
    filled: false,
    contentPadding: const EdgeInsets.only(top: 8, bottom: 12),
    border: InputBorder.none,
    enabledBorder: const UnderlineInputBorder(
      borderSide: BorderSide(color: Colors.white24),
    ),
    focusedBorder: const UnderlineInputBorder(
      borderSide: BorderSide(color: Palette.teal03, width: 1.5),
    ),
    labelText: label,
    labelStyle: const TextStyle(
      color: Palette.teal03,
      fontSize: 14.5,
      fontWeight: FontWeight.w600,
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF030A0B),
      body: AuthBackground(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(26, 12, 26, 30),
          children: [
            const SizedBox(height: 14),
            const Center(
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(text: 'Log in to '),
                    TextSpan(
                      text: 'UniCom',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        decoration: TextDecoration.underline,
                        decorationColor: Palette.teal03,
                        decorationThickness: 3,
                        decorationStyle: TextDecorationStyle.solid,
                      ),
                    ),
                  ],
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Welcome back! Sign in to continue the conversation in your '
              'language.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                height: 1.5,
                color: Colors.white.withValues(alpha: .72),
              ),
            ),
            const SizedBox(height: 30),
            TextField(
              controller: _email,
              keyboardType: TextInputType.text,
              autofillHints: const [AutofillHints.username],
              onChanged: (_) => setState(() {}),
              style: const TextStyle(color: Colors.white),
              cursorColor: Palette.teal03,
              decoration: underline('Username'),
            ),
            const SizedBox(height: 18),
            TextField(
              controller: _password,
              obscureText: _obscure,
              onChanged: (_) => setState(() {}),
              style: const TextStyle(color: Colors.white),
              cursorColor: Palette.teal03,
              decoration: underline('Password').copyWith(
                suffixIcon: IconButton(
                  onPressed: () => setState(() => _obscure = !_obscure),
                  icon: Icon(
                    _obscure
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    size: 20,
                    color: Palette.teal03,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 38),
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
                        : const Text('Log in'),
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: GestureDetector(
                onTap: () {},
                child: const Text(
                  'Forgot password?',
                  style: TextStyle(
                    color: Palette.teal03,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Center(
              child: Text.rich(
                TextSpan(
                  style: TextStyle(
                    fontSize: 13.5,
                    color: Colors.white.withValues(alpha: .72),
                  ),
                  children: [
                    const TextSpan(text: 'New to UniCom? '),
                    WidgetSpan(
                      alignment: PlaceholderAlignment.middle,
                      child: GestureDetector(
                        onTap: () => context.go('/auth/register'),
                        child: const Text(
                          'Sign up',
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
            const SizedBox(height: 20),
            Center(
              child: Text(
                'QUICK TEST ACCOUNTS',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: .55),
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.4,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _loading ? null : () => _quickSignIn('alex'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white24),
                    ),
                    child: const Text('Sign in as Alex'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: _loading ? null : () => _quickSignIn('maya'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white24),
                    ),
                    child: const Text('Sign in as Maya'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            const Center(child: UniComLogo(size: 34)),
          ],
        ),
      ),
    );
  }
}
