import 'package:flutter/material.dart';

/// UniCom design tokens — "Brand Teal" edition.
///
/// A restrained, accessible system: deep charcoal surfaces with a cool
/// undertone, a controlled teal brand accent, blue as a sparse secondary,
/// and semantic colours used for state — never decoration. Token names are
/// kept stable across redesigns so widgets don't churn; only values change.
///
/// Contrast notes (vs. bg #070C0D): textPrimary ≈ 15:1, textSecondary ≈ 8:1,
/// teal accent ≈ 7:1 — all comfortably above WCAG AA for their roles.
abstract final class Palette {
  // ── Core surfaces (deep charcoal, cool undertone) ─────────────────────────
  /// Primary background — the app canvas.
  static const Color bg = Color(0xFF070C0D);

  /// Secondary background — bars, headers, recessed areas.
  static const Color bg2 = Color(0xFF0C1214);

  /// Elevated card / conversation surface — slightly lighter charcoal.
  static const Color card = Color(0xFF121A1C);

  /// Input / chip background — distinct neutral dark surface.
  static const Color input = Color(0xFF182226);

  /// Subtle hairline borders and dividers.
  static const Color border = Color(0xFF22302F);

  // ── Brand (controlled teal) ───────────────────────────────────────────────
  /// Primary brand accent — controlled teal/turquoise.
  static const Color teal = Color(0xFF2BB8AC);

  /// Deep teal for gradients and pressed states.
  static const Color tealDeep = Color(0xFF1B8F86);

  /// Sparse secondary accent — blue (links, info, media).
  static const Color blue = Color(0xFF4C9EEB);

  static const Color cyan = teal;
  static const Color cyan2 = tealDeep;

  /// Legacy aliases kept so existing widgets don't churn.
  /// `iris` is the primary action color (now brand teal).
  static const Color iris = Color(0xFF2BB8AC);
  static const Color irisDeep = Color(0xFF1B8F86);
  static const Color irisDark = Color(0xFF1B8F86);
  static const Color violet = Color(0xFF1B8F86);
  static const Color violetDeep = Color(0xFF146F69);
  static const Color teal03 = Color(0xFF8ADBD3);

  /// Primary action gradient — the one restrained gradient we allow
  /// (logo, primary CTA, small brand moments only).
  // ── Accent (restrained orange — voice recording / sparse highlights) ────
  static const Color orange = Color(0xFFE0784A);
  static const Color orangeHi = Color(0xFFE8875A);
  static const Color orangeSoft = Color(0xFF2A1E16);

  /// Quiet teal tint used for chips and selected states.
  static const Color cyanSoft = Color(0xFF14302E);

  static const LinearGradient brand = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [teal, tealDeep],
    stops: [0.0, 1.0],
  );

  static const LinearGradient brandSoft = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF10201F), Color(0xFF0D1A19)],
  );

  // ── Structural chrome ─────────────────────────────────────────────────────
  /// Top header band (Home / Calls / Contacts / Settings).
  static const Color darkHeader = Color(0xFF070C0D);
  static const Color darkHeaderElev = Color(0xFF0C1214);

  /// Welcome/auth hero.
  static const Color welcome1 = Color(0xFF0E2B29);
  static const Color welcome2 = Color(0xFF070C0D);

  // ── Semantic states (communicate state, not decoration) ──────────────────
  static const Color success = Color(0xFF3DA870);
  static const Color successSoft = Color(0xFF12241B);
  static const Color warning = Color(0xFFD9A13B);
  static const Color warningSoft = Color(0xFF2A2312);
  static const Color danger = Color(0xFFE5566A);
  static const Color dangerSoft = Color(0xFF2A1319);
  static const Color info = Color(0xFF4C9EEB);

  static const Color online = Color(0xFF3DA870);
  static const Color missed = Color(0xFFE5566A);

  // ── Text (warm white, readable muted grey) ────────────────────────────────
  static const Color textPrimary = Color(0xFFF2F4F3);
  static const Color textSecondary = Color(0xFF9AA7A6);
  static const Color textMuted = Color(0xFF637372);

  // ── Light theme (secondary; app is dark-first) ────────────────────────────
  static const Color lightBg = Color(0xFFF4F6F6);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightCard = Color(0xFFFFFFFF);
  static const Color lightInk = Color(0xFF101A1B);
  static const Color lightMuted = Color(0xFF5A6A6A);
  static const Color lightFaint = Color(0xFF879595);
  static const Color lightOutline = Color(0xFFDCE2E2);
  static const Color lightOutline2 = Color(0xFFE4E9E9);
  static const Color lightTrack = Color(0xFFECF0F0);

  /// Incoming (peer) text bubbles — light theme.
  static const Color lightBubbleIn = Color(0xFFEAEFEF);

  // ── Dark theme ───────────────────────────────────────────────────────────
  static const Color darkBg = Color(0xFF070C0D);
  static const Color darkSurface = Color(0xFF0C1214);
  static const Color darkCard = Color(0xFF121A1C);
  static const Color darkCard2 = Color(0xFF182226);
  static const Color darkInk = Color(0xFFF2F4F3);
  static const Color darkMuted = Color(0xFF9AA7A6);
  static const Color darkFaint = Color(0xFF637372);
  static const Color darkOutline = Color(0xFF22302F);

  /// Incoming bubble — slightly lighter charcoal.
  static const Color darkBubbleIn = Color(0xFF121A1C);

  /// Outgoing bubble — restrained dark-teal solid (not neon, no border glow).
  static const Color bubbleOut = Color(0xFF143634);
  static const Color bubbleOutLight = Color(0xFFD5EFEA);

  static const Color darkTrack = Color(0xFF1D282A);

  // ── Avatar pastels (fallback gradient circles when no photo) ─────────────
  static const List<List<Color>> avatarSpectrum = [
    [Color(0xFF2BB8AC), Color(0xFF1B8F86)], // teal (brand)
    [Color(0xFF4C9EEB), Color(0xFF2F6FC4)], // blue
    [Color(0xFF3DA870), Color(0xFF2C7E54)], // green
    [Color(0xFF7C6CFF), Color(0xFF57489E)], // indigo
    [Color(0xFFD9A13B), Color(0xFFA9782A)], // amber
    [Color(0xFFE06C7E), Color(0xFFB04C60)], // rose
    [Color(0xFF5FA8D9), Color(0xFF3E7FB0)], // sky
    [Color(0xFF9B8CFF), Color(0xFF7769C7)], // lavender
  ];

  /// Accent chips (tags / poll highlight) — quiet teal tint, no neon.
  static const Color chipMint = Color(0xFF12302D);
  static const Color chipMintInk = Color(0xFF8ADBD3);

  /// Presence ring for status avatars.
  static const Color statusRing = Color(0xFF2BB8AC);
}
