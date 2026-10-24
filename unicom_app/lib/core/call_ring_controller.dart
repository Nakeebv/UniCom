import 'dart:async';

import 'package:flutter/services.dart';

/// Controls ringtone playback and vibration for incoming calls.
///
/// Uses the platform's own audio alert (SystemSound) + haptic vibration
/// pattern so no external asset or audio-player dependency is needed.
/// A single loop prevents duplicate ringtone overlaps.
class CallRingController {
  static CallRingController? _instance;
  factory CallRingController() => _instance ??= CallRingController._();

  CallRingController._();

  Timer? _vibrateTimer;
  bool _ringing = false;

  void startRinging() {
    if (_ringing) return; // idempotent
    _ringing = true;
    // Initial haptic pattern
    HapticFeedback.heavyImpact();
    // Vibrate every 800ms like a phone ring
    _vibrateTimer = Timer.periodic(const Duration(milliseconds: 800), (_) {
      HapticFeedback.mediumImpact();
      SystemSound.play(SystemSoundType.alert);
    });
    SystemSound.play(SystemSoundType.alert);
  }

  void stopRinging() {
    if (!_ringing) return;
    _ringing = false;
    _vibrateTimer?.cancel();
    _vibrateTimer = null;
  }

  void dispose() {
    stopRinging();
  }
}
