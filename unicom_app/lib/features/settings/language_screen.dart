import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/palette.dart';
import '../../data/models/language.dart';
import '../../providers.dart';

/// Language capability registry browser + display-language picker.
class LanguageScreen extends ConsumerStatefulWidget {
  const LanguageScreen({super.key});

  @override
  ConsumerState<LanguageScreen> createState() => _LanguageScreenState();
}

class _LanguageScreenState extends ConsumerState<LanguageScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final backend = ref.watch(backendProvider);
    final me = backend.me;
    if (me == null) return const SizedBox.shrink();

    final langs =
        LanguageRegistry.all
            .where(
              (l) =>
                  l.name.toLowerCase().contains(_query) ||
                  l.nativeName.toLowerCase().contains(_query),
            )
            .toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Language')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 6, 20, 10),
            child: TextField(
              onChanged: (v) => setState(() => _query = v.toLowerCase()),
              decoration: InputDecoration(
                hintText: 'Search registry…',
                prefixIcon: const Icon(Icons.search_rounded, size: 21),
                suffixIcon:
                    _query.isEmpty
                        ? null
                        : IconButton(
                          icon: const Icon(Icons.close_rounded, size: 18),
                          onPressed: () => setState(() => _query = ''),
                        ),
              ),
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 2, 20, 24),
              itemCount: langs.length + 1,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, i) {
                if (i == 0) {
                  return _activeCard(
                    context,
                    me.languageCode,
                    me.speechLanguageCode,
                  );
                }
                final l = langs[i - 1];
                return _langCard(context, l, me.languageCode == l.code, () async {
                  final ctx = context;
                  await backend.setLanguage(l.code);
                  if (ctx.mounted) {
                    setState(() {});
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(
                        content: Text(
                          'UniCom now translates incoming messages into ${l.nativeName}',
                        ),
                      ),
                    );
                  }
                });
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _activeCard(BuildContext context, String code, String? speechCode) {
    final l = LanguageRegistry.of(code);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: Palette.brand,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          const Icon(Icons.verified_rounded, color: Colors.white, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Active configuration',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 14.5,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Display: ${l.flag} ${l.nativeName} · Voice notes: ${LanguageRegistry.of(speechCode ?? code).nativeName}',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: .85),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _langCard(
    BuildContext context,
    LanguageInfo l,
    bool active,
    VoidCallback onPick,
  ) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: l.translatable ? onPick : null,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color:
                  active ? Palette.iris : scheme.outline.withValues(alpha: .8),
              width: active ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Text(l.flag, style: const TextStyle(fontSize: 24)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          l.nativeName,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 14.5,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          l.name,
                          style: TextStyle(
                            fontSize: 12,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 7),
                    Wrap(
                      spacing: 5,
                      runSpacing: 5,
                      children: [
                        _cap(l.mt, 'MT'),
                        _cap(l.stt, 'STT'),
                        _cap(l.tts, 'TTS'),
                        _cap(l.detection, 'Detect'),
                      ],
                    ),
                    if (l.note != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        l.note!,
                        style: TextStyle(
                          fontSize: 11,
                          height: 1.35,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (active)
                const Icon(
                  Icons.check_circle_rounded,
                  color: Palette.iris,
                  size: 22,
                )
              else if (!l.translatable)
                const Icon(Icons.block_rounded, size: 18, color: Colors.grey)
              else
                const Icon(
                  Icons.radio_button_unchecked_rounded,
                  size: 20,
                  color: Colors.grey,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _cap(bool supported, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
      decoration: BoxDecoration(
        color:
            supported
                ? Palette.success.withValues(alpha: .12)
                : Colors.grey.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9.5,
          fontWeight: FontWeight.w800,
          letterSpacing: .3,
          color: supported ? Palette.success : Palette.textMuted,
        ),
      ),
    );
  }
}
