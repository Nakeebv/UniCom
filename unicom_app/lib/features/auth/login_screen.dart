import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/palette.dart';
import '../../shared/widgets/ui_kit.dart';
import '../../providers.dart';
import '../../shared/widgets/logo.dart';

/// Kit login: underline fields, teal labels, disabled→enabled pill.
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
      RegExp(r'.+@.+\..+').hasMatch(_email.text) && _password.text.isNotEmpty;

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

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final ink = scheme.onSurface;

    InputDecoration underline(String label) => InputDecoration(
      filled: false,
      contentPadding: const EdgeInsets.only(top: 8, bottom: 12),
      border: InputBorder.none,
      enabledBorder: const UnderlineInputBorder(
        borderSide: BorderSide(color: Palette.border),
      ),
      focusedBorder: const UnderlineInputBorder(
        borderSide: BorderSide(color: Palette.iris),
      ),
      labelText: label,
      labelStyle: const TextStyle(
        color: Palette.iris,
        fontSize: 14.5,
        fontWeight: FontWeight.w600,
      ),
    );

    Widget socialCircle(IconData icon, Color color) => Container(
      width: 54,
      height: 54,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: scheme.outline),
      ),
      child: Icon(icon, size: 25, color: color),
    );

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        foregroundColor: ink,
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
                      const TextSpan(text: 'Log in to '),
                      TextSpan(
                        text: 'UniCom',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: ink,
                          decoration: TextDecoration.underline,
                          decorationColor: Palette.teal03,
                          decorationThickness: 3,
                          decorationStyle: TextDecorationStyle.solid,
                        ),
                      ),
                    ],
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: ink,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Welcome back! Sign in to continue the conversation in your language.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.5,
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 26),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  socialCircle(Icons.facebook_rounded, const Color(0xFF1877F2)),
                  const SizedBox(width: 18),
                  socialCircle(Icons.public_rounded, const Color(0xFFEA4335)),
                  const SizedBox(width: 18),
                  socialCircle(
                    Icons.apple_rounded,
                    Theme.of(context).colorScheme.onSurface,
                  ),
                ],
              ),
              const SizedBox(height: 26),
              Center(
                child: Text(
                  'OR',
                  style: TextStyle(
                    color: scheme.onSurfaceVariant.withValues(alpha: .8),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 2.4,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                onChanged: (_) => setState(() {}),
                decoration: underline('Your Email'),
              ),
              const SizedBox(height: 18),
              TextField(
                controller: _password,
                obscureText: _obscure,
                onChanged: (_) => setState(() {}),
                decoration: underline('Password').copyWith(
                  suffixIcon: IconButton(
                    onPressed: () => setState(() => _obscure = !_obscure),
                    icon: Icon(
                      _obscure
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      size: 20,
                      color: Palette.iris,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 40),
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
                      color: Palette.iris,
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
                      color: scheme.onSurfaceVariant,
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
              const SizedBox(height: 18),
              const Center(child: UniComLogo(size: 34)),
            ],
          ),
        ),
      ),
    );
  }
}
