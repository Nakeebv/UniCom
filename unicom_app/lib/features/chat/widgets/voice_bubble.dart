import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/audio/playback_service.dart';
import '../../../core/theme/palette.dart';
import '../../../data/models/language.dart';
import '../../../data/models/message.dart';
import '../../../providers.dart';
import '../../../shared/widgets/ui_kit.dart';
import 'waveform.dart';

/// Renders a voice-note message: pipeline stepper while processing, then
/// player + transcript controls. Mirrors the "partial"/"unavailable"
/// fallback states from the architecture doc.
class VoiceBubbleView extends ConsumerStatefulWidget {
  const VoiceBubbleView({
    super.key,
    required this.voice,
    required this.sourceLanguage,
    required this.targetLanguage,
    required this.isMine,
    required this.createdAt,
    required this.onRetry,
  });

  final VoicePayload voice;
  final VoidCallback onRetry;
  final String? sourceLanguage;
  final String targetLanguage;
  final bool isMine;
  final DateTime createdAt;

  @override
  ConsumerState<VoiceBubbleView> createState() => _VoiceBubbleViewState();
}

class _VoiceBubbleViewState extends ConsumerState<VoiceBubbleView> {
  bool _playingOriginal = false;
  bool _playingTranslated = false;
  bool _showTranscript = false;

  bool get _busy => widget.voice.stage.isBusy;

  // ── Real audio playback ─────────────────────────────────────────────────
  VoicePlaybackController? _player;
  StreamSubscription<Duration>? _posSub;
  StreamSubscription<bool>? _playSub;
  Duration _position = Duration.zero;
  bool _realPlaying = false;
  bool _audioUnsupported = false;
  bool _autoPlayed = false;

  bool get _translatedAudioReady =>
      widget.voice.audioVariants[widget.targetLanguage] == true;

  /// Which audio the "play" main button will use, honouring the user's
  /// default-version preference when both exist.
  bool get _defaultWantsTranslated =>
      !(ref.read(backendProvider).preferOriginalAudio) && _translatedAudioReady;

  String? _loadedKey;

  Future<void> _ensureLoaded({required bool translated}) async {
    if (_player != null && _loadedKey == _variantKey(translated)) {
      return;
    }
    await _teardownPlayer();
    final controller = VoicePlaybackController();
    try {
      await controller.loadSame(
        cacheKey: _variantKey(translated),
        filePath: widget.voice.recordedFilePath,
        declaredDuration: widget.voice.duration,
        onCompleted: () {
          if (mounted) {
            setState(() {
              _realPlaying = false;
              _position = Duration.zero;
            });
          }
        },
      );
      controller.setRate(ref.read(backendProvider).playbackRate);
      _posSub = controller.positionStream().listen((d) {
        if (mounted) setState(() => _position = d);
      });
      _playSub = controller.playingStream().listen((playing) {
        if (mounted) setState(() => _realPlaying = playing);
      });
      _player = controller;
      _loadedKey = _variantKey(translated);
    } catch (_) {
      _audioUnsupported = true;
    }
    if (mounted) setState(() {});
  }

  String _variantKey(bool translated) =>
      '${widget.voice.jobId}::${translated ? widget.targetLanguage : "orig"}';

  Future<void> _teardownPlayer() async {
    await _posSub?.cancel();
    await _playSub?.cancel();
    await _player?.dispose();
    _posSub = null;
    _playSub = null;
    _player = null;
  }

  Future<void> _toggle() async {
    if (_audioUnsupported) return;
    final wantTranslated =
        _playingTranslated || (_defaultWantsTranslated && !_playingOriginal);
    final translated = wantTranslated && _translatedAudioReady;
    await _ensureLoaded(translated: translated);
    if (_audioUnsupported) {
      if (mounted) setState(() {});
      return;
    }
    if (_realPlaying) {
      await _player!.pause();
    } else {
      if (translated) {
        _playingTranslated = true;
        _playingOriginal = false;
      } else {
        _playingOriginal = true;
        _playingTranslated = false;
      }
      await _player!.play();
    }
    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(covariant VoiceBubbleView old) {
    super.didUpdateWidget(old);
    // Auto-play translated audio once, only if the user opted in. Off by
    // default — receiving sound unprompted is invasive.
    final backend = ref.read(backendProvider);
    if (!widget.isMine &&
        backend.autoPlayTranslated &&
        widget.voice.stage == VoiceStage.completed &&
        !_autoPlayed &&
        _translatedAudioReady) {
      _autoPlayed = true;
      Future<void>.delayed(const Duration(milliseconds: 350), () {
        if (mounted) _toggle();
      });
    }
  }

  @override
  void dispose() {
    _teardownPlayer();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final v = widget.voice;
    if (v.stage == VoiceStage.failedRetryable ||
        v.stage == VoiceStage.failedPermanent) {
      return _failed();
    }
    if (v.stage == VoiceStage.cancelled) {
      return _cancelled();
    }
    if (_busy || v.stage == VoiceStage.partial) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _stepper(),
          if (v.transcript != null) ...[
            const SizedBox(height: 10),
            _transcriptPreview(),
          ],
          if (v.stage == VoiceStage.partial && v.error != null) ...[
            const SizedBox(height: 10),
            _partialError(),
          ],
        ],
      );
    }
    // completed
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _playerView(strip: false),
        const SizedBox(height: 10),
        _languageSwap(),
        AnimatedSize(
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child:
              _showTranscript
                  ? _transcriptSheet()
                  : const SizedBox(width: double.infinity),
        ),
      ],
    );
  }

  // ── Pipeline stepper ─────────────────────────────────────────────────────
  Widget _stepper() {
    const order = [
      VoiceStage.uploading,
      VoiceStage.queued,
      VoiceStage.transcribing,
      VoiceStage.translating,
      VoiceStage.synthesizing,
      VoiceStage.completed,
    ];
    final labels = {
      VoiceStage.uploading: 'Uploading',
      VoiceStage.queued: 'Queued',
      VoiceStage.transcribing: 'Transcribing',
      VoiceStage.translating: 'Translating',
      VoiceStage.synthesizing: 'Speech',
      VoiceStage.completed: 'Ready',
    };
    int activeIdx = order.indexOf(widget.voice.stage);
    if (activeIdx < 0) activeIdx = 3;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: List.generate(order.length * 2 - 1, (i) {
            if (i.isOdd) {
              final done = i ~/ 2 < activeIdx;
              return Expanded(
                child: Container(
                  height: 2,
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  color:
                      done ? Palette.iris : Palette.iris.withValues(alpha: .18),
                ),
              );
            }
            final idx = i ~/ 2;
            final done = idx < activeIdx;
            final active = idx == activeIdx;
            return Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                gradient: done || active ? Palette.brand : null,
                color:
                    done || active ? null : Palette.iris.withValues(alpha: .12),
                shape: BoxShape.circle,
              ),
              child:
                  done
                      ? const Icon(
                        Icons.check_rounded,
                        size: 12,
                        color: Colors.white,
                      )
                      : active
                      ? const Padding(
                        padding: EdgeInsets.all(5),
                        child: CircularProgressIndicator(
                          strokeWidth: 1.6,
                          valueColor: AlwaysStoppedAnimation(Colors.white),
                        ),
                      )
                      : null,
            );
          }),
        ),
        const SizedBox(height: 8),
        Text(
          widget.voice.stage == VoiceStage.partial
              ? widget.voice.error ?? 'Partial — audio unavailable'
              : '${labels[order[activeIdx.clamp(0, 4)]]}… ${LanguageRegistry.of(widget.targetLanguage).flag} ${LanguageRegistry.of(widget.targetLanguage).nativeName}',
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            color:
                widget.voice.stage == VoiceStage.partial
                    ? Palette.warning
                    : Palette.irisDark,
          ),
        ),
        const SizedBox(height: 8),
        const ShimmerBox(width: 190, height: 9),
        const SizedBox(height: 6),
        const ShimmerBox(width: 130, height: 9),
      ],
    );
  }

  Widget _transcriptPreview() {
    final detected = LanguageRegistry.of(
      widget.voice.detectedLanguage ?? widget.sourceLanguage,
    );
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: (widget.isMine ? Colors.white : Palette.iris).withValues(
          alpha: widget.isMine ? .14 : .08,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${detected.flag} ${detected.nativeName} · detecting speech',
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color:
                  widget.isMine
                      ? Colors.white.withValues(alpha: .85)
                      : Palette.irisDark,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            widget.voice.transcript ?? '',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12.5,
              height: 1.4,
              color:
                  widget.isMine
                      ? Colors.white.withValues(alpha: .92)
                      : Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  Widget _partialError() {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: Palette.warning.withValues(alpha: .14),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Palette.warning.withValues(alpha: .45)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.info_outline_rounded,
            size: 17,
            color: Color(0xFFB45309),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Text is ready, but spoken audio is not available for this '
              'language in the demo',
              style: TextStyle(
                fontSize: 11.5,
                height: 1.35,
                fontWeight: FontWeight.w600,
                color:
                    scheme.brightness == Brightness.dark
                        ? const Color(0xFFFCD34D)
                        : const Color(0xFF92400E),
              ),
            ),
          ),
          const SizedBox(width: 6),
          GhostButton(
            label: 'Retry',
            icon: Icons.refresh_rounded,
            onPressed: widget.onRetry,
          ),
        ],
      ),
    );
  }

  // ── Completed player ─────────────────────────────────────────────────────
  Widget _playerView({required bool strip}) {
    final playing = _realPlaying || _playingOriginal || _playingTranslated;
    final translatedPlaying = _playingTranslated && _playingOriginal == false;
    final samples = widget.voice.waveform;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        WaveformView(
          samples: samples,
          duration: widget.voice.duration,
          position: _position,
          onSeek: (frac) async {
            if (_audioUnsupported) return;
            final wantTranslated =
                _playingTranslated ||
                (_defaultWantsTranslated && !_playingOriginal);
            await _ensureLoaded(
              translated: wantTranslated && _translatedAudioReady,
            );
            await _player?.seekFraction(frac);
          },
          playing: playing,
          onToggle: _toggle,
          playedColor:
              widget.isMine
                  ? Colors.white
                  : (translatedPlaying ? Palette.teal : Palette.teal),
          color:
              widget.isMine
                  ? Colors.white.withValues(alpha: .4)
                  : Theme.of(
                    context,
                  ).colorScheme.onSurfaceVariant.withValues(alpha: .3),
        ),
        // Honest source caption: real recording vs demo variant audio.
        if (_playingTranslated && _translatedAudioReady && !widget.isMine)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'Translated speech (demo audio)',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        if (_playingOriginal && !widget.isMine)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              widget.voice.recordedFilePath != null
                  ? 'Original recording'
                  : 'Original audio (demo)',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        if (_audioUnsupported)
          const Padding(
            padding: EdgeInsets.only(top: 4),
            child: Text(
              'Audio playback unavailable in this environment',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: Palette.warning,
              ),
            ),
          ),
      ],
    );
  }

  /// Original ⇄ translated variant switcher.
  Widget _languageSwap() {
    final source = LanguageRegistry.of(widget.sourceLanguage);
    final target = LanguageRegistry.of(widget.targetLanguage);
    final translatedReady =
        widget.voice.audioVariants[widget.targetLanguage] == true;
    final sameLang = source.code == target.code;

    if (sameLang) {
      return Capsule(
        icon: Icons.mic_none_rounded,
        label: '${source.nativeName} voice note',
      );
    }

    return Row(
      children: [
        Flexible(
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              // Labels come from the actual source/target languages —
              // "Play original / Play in Yorùbá" — never hardcoded.
              Semantics(
                button: true,
                label: 'Play original',
                child: _VariantChip(
                  flag: source.flag,
                  label: 'Original',
                  selected: _playingOriginal || !_playingTranslated,
                  onTap:
                      () => setState(() {
                        _playingOriginal = true;
                        _playingTranslated = false;
                      }),
                ),
              ),
              Semantics(
                button: true,
                label: 'Play in ${target.nativeName}',
                child: _VariantChip(
                  flag: target.flag,
                  label: target.nativeName,
                  selected: _playingTranslated,
                  enabled: translatedReady,
                  onTap:
                      translatedReady
                          ? () => setState(() {
                            _playingTranslated = true;
                            _playingOriginal = false;
                          })
                          : null,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 6),
        _TranscriptToggle(
          onTap: () => setState(() => _showTranscript = !_showTranscript),
        ),
      ],
    );
  }

  Widget _transcriptSheet() {
    final source = LanguageRegistry.of(widget.sourceLanguage);
    final target = LanguageRegistry.of(widget.targetLanguage);
    final sameLang = source.code == target.code;
    final translated =
        widget.voice.translatedTranscripts[widget.targetLanguage];

    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: (widget.isMine ? Colors.white : Palette.iris).withValues(
          alpha: widget.isMine ? .13 : .07,
        ),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!sameLang && translated != null) ...[
            Row(
              children: [
                Text(target.flag, style: const TextStyle(fontSize: 13)),
                const SizedBox(width: 6),
                Text(
                  'In ${target.nativeName}',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    color:
                        widget.isMine
                            ? Colors.white.withValues(alpha: .8)
                            : Palette.irisDark,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 5),
            Text(
              translated,
              style: TextStyle(
                fontSize: 13,
                height: 1.45,
                fontWeight: FontWeight.w600,
                color:
                    widget.isMine
                        ? Colors.white
                        : Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              Text(source.flag, style: const TextStyle(fontSize: 12)),
              const SizedBox(width: 6),
              Text(
                'Original transcript',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  color:
                      widget.isMine
                          ? Colors.white.withValues(alpha: .66)
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            widget.voice.transcript ?? '—',
            style: TextStyle(
              fontSize: 12.5,
              height: 1.45,
              color:
                  widget.isMine
                      ? Colors.white.withValues(alpha: .94)
                      : Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _failed() {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(Icons.mic_off_rounded, size: 18, color: scheme.error),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'Voice processing failed — the original audio is still playable.',
            style: TextStyle(
              fontSize: 12.5,
              height: 1.35,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ),
        GhostButton(
          label: 'Retry',
          icon: Icons.refresh_rounded,
          onPressed: widget.onRetry,
        ),
      ],
    );
  }

  Widget _cancelled() {
    return Row(
      children: [
        const Icon(Icons.cancel_outlined, size: 17),
        const SizedBox(width: 8),
        Text(
          'Voice note cancelled',
          style: TextStyle(
            fontSize: 12.5,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _VariantChip extends StatelessWidget {
  const _VariantChip({
    required this.flag,
    required this.label,
    required this.selected,
    this.enabled = true,
    this.onTap,
  });

  final String flag;
  final String label;
  final bool selected;
  final bool enabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabledColor =
        selected ? Palette.iris : Palette.iris.withValues(alpha: .55);
    return Opacity(
      opacity: enabled ? 1 : .45,
      child: Material(
        color:
            selected ? Palette.iris.withValues(alpha: .14) : Colors.transparent,
        borderRadius: BorderRadius.circular(999),
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(999),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color:
                    selected
                        ? Palette.iris
                        : enabledColor.withValues(alpha: .5),
              ),
            ),
            child: Row(
              children: [
                Text(flag, style: const TextStyle(fontSize: 12)),
                const SizedBox(width: 5),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: selected ? Palette.irisDark : enabledColor,
                  ),
                ),
                if (selected) ...[
                  const SizedBox(width: 5),
                  const Icon(
                    Icons.graphic_eq_rounded,
                    size: 12,
                    color: Palette.irisDark,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TranscriptToggle extends StatelessWidget {
  const _TranscriptToggle({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(
        context,
      ).colorScheme.onSurfaceVariant.withValues(alpha: .1),
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 9, vertical: 6),
          child: Icon(Icons.receipt_long_rounded, size: 14),
        ),
      ),
    );
  }
}
