import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/palette.dart';
import '../../data/models/voice_catalog.dart';
import '../../data/models/language.dart';
import '../../providers.dart';
import '../../shared/widgets/ui_kit.dart';

/// Speech language + synthesized-voice selection.
class VoiceScreen extends ConsumerWidget {
  const VoiceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final backend = ref.watch(backendProvider);
    final me = backend.me;
    if (me == null) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;

    final speechOptions =
        LanguageRegistry.all.where((l) => l.stt && l.tts).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Voice & speech')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        children: [
          const SectionHeader('Voice notes recorded in'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children:
                speechOptions.map((l) {
                  final active =
                      (me.speechLanguageCode ?? me.languageCode) == l.code;
                  return Material(
                    color:
                        active
                            ? Palette.iris.withValues(alpha: .13)
                            : Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(999),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(999),
                      onTap: () async {
                        await backend.setSpeechLanguage(l.code);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 13,
                          vertical: 9,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: active ? Palette.iris : scheme.outline,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(l.flag, style: const TextStyle(fontSize: 15)),
                            const SizedBox(width: 7),
                            Text(
                              l.nativeName,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight:
                                    active ? FontWeight.w800 : FontWeight.w600,
                                color:
                                    active
                                        ? Palette.irisDark
                                        : scheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
          ),
          const SectionHeader('Translation & playback'),
          _SwitchRow(
            icon: Icons.translate_rounded,
            title: 'Automatic translation',
            subtitle:
                'Translate incoming messages and voice notes as they arrive. '
                'Off = use the View-translation control manually.',
            value: backend.autoTranslate,
            onChanged: (v) => backend.setAutoTranslate(v),
          ),
          _SwitchRow(
            icon: Icons.graphic_eq_rounded,
            title: 'Auto-play translated audio',
            subtitle:
                'Off by default — UniCom never starts sound on its own '
                'unless you allow it here.',
            value: backend.autoPlayTranslated,
            onChanged: (v) => backend.setAutoPlayTranslated(v),
          ),
          _SwitchRow(
            icon: Icons.record_voice_over_outlined,
            title: 'Play original audio first',
            subtitle:
                'When both versions exist, start with the sender\'s real '
                'voice instead of the synthesized translation.',
            value: backend.preferOriginalAudio,
            onChanged: (v) => backend.setPreferOriginalAudio(v),
          ),
          _SpeedRow(value: backend.playbackRate),
          const SectionHeader('Synthesized voice · for your language'),
          Text(
            'Recipients hear translated speech in this voice (when their '
            'language supports synthesis). Sender-voice cloning is a future, '
            'consent-gated feature.',
            style: TextStyle(
              fontSize: 12.5,
              height: 1.5,
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          ...VoiceCatalog.voices.map(
            (v) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _VoiceCard(
                voice: v,
                selected:
                    me.voiceId == v.id ||
                    (me.voiceId == null && v.id == 'aria'),
                onTap: () => backend.setVoice(v.id),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _VoiceCard extends StatelessWidget {
  const _VoiceCard({
    required this.voice,
    required this.selected,
    required this.onTap,
  });

  final VoiceOption voice;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color:
                  selected
                      ? Palette.iris
                      : scheme.outline.withValues(alpha: .8),
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  gradient: selected ? Palette.brand : _idleGrad,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(
                  Icons.record_voice_over_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          voice.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 14.5,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(voice.flag, style: const TextStyle(fontSize: 13)),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      voice.tag,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                selected
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_unchecked_rounded,
                color: selected ? Palette.iris : Colors.grey,
                size: 21,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

const LinearGradient _idleGrad = LinearGradient(
  colors: [Color(0xFFD6DAF5), Color(0xFFE3D9F8)],
);

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Palette.chipMint.withValues(alpha: .5),
          borderRadius: BorderRadius.circular(13),
        ),
        child: Icon(icon, size: 20, color: Palette.chipMintInk),
      ),
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.4),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 2),
        child: Text(
          subtitle,
          style: const TextStyle(fontSize: 11.8, color: Palette.textSecondary),
        ),
      ),
      isThreeLine: true,
      trailing: Switch(value: value, onChanged: onChanged),
    );
  }
}

class _SpeedRow extends ConsumerWidget {
  const _SpeedRow({required this.value});

  final double value;

  static const _labels = ['0.75×', '1×', '1.25×', '1.5×', '2×'];
  static const _values = [0.75, 1.0, 1.25, 1.5, 2.0];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final backend = ref.watch(backendProvider);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 6, 4, 10),
      child: Row(
        children: [
          const Icon(
            Icons.speed_rounded,
            size: 19,
            color: Palette.textSecondary,
          ),
          const SizedBox(width: 12),
          const Text(
            'Playback speed',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14.4),
          ),
          const Spacer(),
          SegmentedButton<double>(
            showSelectedIcon: false,
            selected: {
              _values[_values.indexWhere((v) => (v - value).abs() < .01)],
            },
            onSelectionChanged: (sel) {
              backend.setPlaybackRate(sel.first);
            },
            segments: [
              for (var i = 0; i < _values.length; i++)
                ButtonSegment(
                  value: _values[i],
                  label: Text(_labels[i], style: const TextStyle(fontSize: 11)),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
