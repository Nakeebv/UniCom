import 'dart:math';

import 'package:flutter/material.dart';

abstract final class App {
  static const String name = 'UniCom';
  static const String tagline = 'Unified Global Communications';
  static const String version = '0.1.0';
  static const String demoNote = 'Demo build — AI providers are simulated.';
}

/// Deterministic tight id generator (demo-safe, no package dependency).
String newId(String prefix) {
  final int ms = DateTime.now().microsecondsSinceEpoch;
  final int rnd = Random(ms % 2147483647).nextInt(0xFFFFF);
  final b36 = ms.toRadixString(36).replaceFirst('-', '');
  return '$prefix'
      '_$b36$rnd';
}

String initialsOf(String name) {
  final parts = name.trim().split(RegExp(r'\s+'))
    ..removeWhere((e) => e.isEmpty);
  if (parts.isEmpty) return '?';
  String firstChar(String s) {
    return String.fromCharCodes(s.runes.take(1)).toUpperCase();
  }

  if (parts.length == 1) return firstChar(parts.first);
  return firstChar(parts.first) + firstChar(parts.last);
}

extension StringX on String {
  String take(int max) =>
      length <= max ? this : '${substring(0, max.clamp(0, length))}…';

  String get capitalized =>
      isEmpty ? this : '${this[0].toUpperCase()}${substring(1)}';
}

extension ColorX on Color {
  Color tint(double a) => withValues(alpha: a.clamp(0.0, 1.0));
}

/// Deterministic hash used for seeded waveforms / avatar gradients.
int stableHash(String source) {
  int h = 0x811c9dc5;
  for (final int c in source.codeUnits) {
    h ^= c;
    h = (h * 0x01000193) & 0x7FFFFFFF;
  }
  return h;
}

/// Formats minute-of-day, e.g. 14:32.
String formatClock(DateTime t) {
  final hh = t.hour.toString().padLeft(2, '0');
  final mm = t.minute.toString().padLeft(2, '0');
  return '$hh:$mm';
}

/// Chat list style: 14:32 · Mon · 12 Mar.
String formatListStamp(DateTime t, DateTime now) {
  final sameDay = _sameDay(t, now);
  if (sameDay) return formatClock(t);
  final yesterday = now.subtract(const Duration(days: 1));
  if (_sameDay(t, yesterday)) return 'Yesterday';
  if (now.difference(t).inDays < 7) {
    return const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][t.weekday -
        1];
  }
  return '${t.day} ${const ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][t.month - 1]}';
}

/// Day divider label.
String formatDayLabel(DateTime t, DateTime now) {
  if (_sameDay(t, now)) return 'Today';
  if (_sameDay(t, now.subtract(const Duration(days: 1)))) return 'Yesterday';
  return '${t.day} ${const ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'][t.month - 1]} ${t.year}';
}

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// 0:07 style durations.
String formatDuration(Duration d) {
  final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
  final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '${d.inHours > 0 ? '${d.inHours}:' : ''}$m:$s';
}
