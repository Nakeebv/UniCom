import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers.dart';

import '../../core/theme/palette.dart';
import '../../shared/widgets/ui_kit.dart';
import '../../shared/widgets/logo.dart';

/// Email verification: 6-digit code emailed via Resend, validated server-side.
class VerifyScreen extends ConsumerStatefulWidget {
  const VerifyScreen({super.key});

  @override
  ConsumerState<VerifyScreen> createState() => _VerifyScreenState();
}

class _VerifyScreenState extends ConsumerState<VerifyScreen> {
  final _focus = FocusNode();
  final List<TextEditingController> _digits = List.generate(
    6,
    (_) => TextEditingController(),
  );
  bool _loading = false;
  String? _error;
  Timer? _resend;
  int _secondsLeft = 30;

  @override
  void initState() {
    super.initState();
    _resend = Timer.periodic(const Duration(seconds: 1), (t) {
      if (mounted && _secondsLeft > 0) {
        setState(() => _secondsLeft -= 1);
      }
    });
  }

  @override
  void dispose() {
    _focus.dispose();
    _resend?.cancel();
    for (final d in _digits) {
      d.dispose();
    }
    super.dispose();
  }

  void _onChange(int index, String value) {
    if (value.length == 6) {
      for (var i = 0; i < 6; i++) {
        _digits[i].text = value[i];
      }
    }
    if (value.length == 1 && index < 5) {
      FocusScope.of(context).nextFocus();
    }
    if (value.isEmpty && index > 0) {
      FocusScope.of(context).previousFocus();
    }
    final code = _digits.map((d) => d.text).join();
    if (code.length == 6) _verify();
  }

  Future<void> _verify() async {
    final code = _digits.map((d) => d.text).join();
    if (code.length != 6) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    final remote = ref.read(backendProvider).asRemote;
    try {
      if (remote != null) {
        await remote.api.verifyEmail(code);
      } else {
        await Future<void>.delayed(const Duration(milliseconds: 400));
      }
      if (!mounted) return;
      context.go('/auth/language');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
      for (final d in _digits) {
        d.clear();
      }
      _focus.requestFocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
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
            padding: const EdgeInsets.fromLTRB(26, 10, 26, 30),
            children: [
              const SizedBox(height: 14),
              Text.rich(
                TextSpan(
                  children: [
                    const TextSpan(text: 'Check your '),
                    TextSpan(
                      text: 'email',
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
              const SizedBox(height: 10),
              Text(
                'We sent a 4-digit code to keep your account recoverable when '
                'you switch devices.',
                style: TextStyle(
                  fontSize: 13,
                  height: 1.55,
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 34),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(6, _otpBox),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 14),
                  child: Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Palette.danger,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              const SizedBox(height: 40),
              SizedBox(
                height: 56,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: Palette.iris,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  onPressed: _loading ? null : _verify,
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
                          : const Text('Verify'),
                ),
              ),
              const SizedBox(height: 18),
              Center(
                child: Text(
                  _secondsLeft > 0
                      ? 'Resend code in 00:${_secondsLeft.toString().padLeft(2, '0')}'
                      : 'Didn\'t get it? Tap Resend',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(height: 30),
              const Center(child: UniComLogo(size: 34)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _otpBox(int i) {
    final filled = _digits[i].text.isNotEmpty;
    return SizedBox(
      width: 62,
      height: 62,
      child: TextField(
        controller: _digits[i],
        focusNode: i == 0 ? _focus : null,
        textAlign: TextAlign.center,
        maxLength: 4,
        keyboardType: TextInputType.number,
        autofocus: i == 0,
        style: const TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: Palette.irisDark,
        ),
        decoration: InputDecoration(
          counterText: '',
          contentPadding: EdgeInsets.zero,
          filled: true,
          fillColor: filled ? Palette.cyanSoft : Palette.darkCard2,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Palette.iris, width: 1.6),
          ),
        ),
        onChanged: (v) => _onChange(i, v),
      ),
    );
  }
}
