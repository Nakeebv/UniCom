import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/palette.dart';
import '../../data/models/voice_catalog.dart';
import '../../data/models/language.dart';
import '../../providers.dart';

/// Language setup onboarding — minimal kit style with quick picks.
class LanguageSetupScreen extends ConsumerStatefulWidget {
  const LanguageSetupScreen({super.key});

  @override
  ConsumerState<LanguageSetupScreen> createState() =>
      _LanguageSetupScreenState();
}

class _LanguageSetupScreenState extends ConsumerState<LanguageSetupScreen> {
  String _query = '';
  String? _selected;
  bool _saving = false;

  static const quickPicks = ['en', 'es', 'yo', 'ha', 'sw', 'ar'];

  Future<void> _finish() async {
    setState(() => _saving = true);
    final backend = ref.read(backendProvider);
    await backend.setLanguage(_selected!);
    await backend.setVoice(VoiceCatalog.voices.first.id);
    backend.seedConversations();
    if (!mounted) return;
    context.go('/chats');
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final langs =
        LanguageRegistry.supported
            .where(
              (l) =>
                  _query.isEmpty ||
                  l.name.toLowerCase().contains(_query) ||
                  l.nativeName.toLowerCase().contains(_query),
            )
            .toList();

    InputDecoration underline() => const InputDecoration(
      filled: false,
      contentPadding: EdgeInsets.only(top: 8, bottom: 12),
      border: InputBorder.none,
      enabledBorder: UnderlineInputBorder(
        borderSide: BorderSide(color: Palette.border),
      ),
      focusedBorder: UnderlineInputBorder(
        borderSide: BorderSide(color: Palette.iris),
      ),
      hintText: 'Search:  Español, Yorùbá, Hausa…',
      hintStyle: TextStyle(
        color: Colors.grey,
        fontWeight: FontWeight.w400,
        fontSize: 14.5,
      ),
    );

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        foregroundColor: scheme.onSurface,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(26, 10, 26, 16),
                children: [
                  Text.rich(
                    TextSpan(
                      children: [
                        const TextSpan(text: 'Choose your '),
                        TextSpan(
                          text: 'language',
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
                    'Every message and voice note UniCom receives will be '
                    'translated into this language.',
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.5,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Quick picks
                  Wrap(
                    spacing: 9,
                    runSpacing: 9,
                    children:
                        quickPicks.map((code) {
                          final l = LanguageRegistry.of(code);
                          final active = _selected == code;
                          return GestureDetector(
                            onTap: () => setState(() => _selected = code),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 13,
                                vertical: 9,
                              ),
                              decoration: BoxDecoration(
                                color:
                                    active
                                        ? Palette.cyanSoft
                                        : Palette.darkCard,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    l.flag,
                                    style: const TextStyle(fontSize: 15),
                                  ),
                                  const SizedBox(width: 7),
                                  Text(
                                    l.nativeName,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight:
                                          active
                                              ? FontWeight.w800
                                              : FontWeight.w600,
                                      color:
                                          active
                                              ? Palette.cyan
                                              : scheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                  ),
                  const SizedBox(height: 26),
                  TextField(
                    onChanged: (v) => setState(() => _query = v.toLowerCase()),
                    decoration: underline(),
                  ),
                  const SizedBox(height: 16),
                  ...langs.map((l) {
                    final active = _selected == l.code;
                    return Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => setState(() => _selected = l.code),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 10,
                          ),
                          child: Row(
                            children: [
                              Text(
                                l.flag,
                                style: const TextStyle(fontSize: 21),
                              ),
                              const SizedBox(width: 13),
                              Expanded(
                                child: Text(
                                  '${l.nativeName}  ·  ${l.name}',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              if (active)
                                const Icon(
                                  Icons.check_circle,
                                  color: Palette.iris,
                                  size: 20,
                                )
                              else
                                Icon(
                                  Icons.circle_outlined,
                                  size: 20,
                                  color: scheme.onSurfaceVariant.withValues(
                                    alpha: .4,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(26, 0, 26, 24),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor:
                        _selected != null ? Palette.cyan : Palette.darkCard2,
                    disabledBackgroundColor: Palette.darkCard2,
                    foregroundColor:
                        _selected != null
                            ? Colors.white
                            : scheme.onSurfaceVariant,
                    disabledForegroundColor: scheme.onSurfaceVariant,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  onPressed: _selected == null || _saving ? null : _finish,
                  child:
                      _saving
                          ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.2,
                              valueColor: AlwaysStoppedAnimation(Colors.white),
                            ),
                          )
                          : Text(
                            _selected == null
                                ? 'Select a language'
                                : 'Continue with ${LanguageRegistry.of(_selected).nativeName}',
                          ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
