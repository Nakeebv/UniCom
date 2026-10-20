import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'palette.dart';

/// UniCom typography — Inter throughout: clean, highly legible, modern.
sealed class AppType {
  static const double displayXL = 30;

  static TextTheme build(Brightness brightness) {
    final base =
        brightness == Brightness.dark
            ? ThemeData.dark().textTheme
            : ThemeData.light().textTheme;
    return GoogleFonts.interTextTheme(base).apply(
      bodyColor:
          brightness == Brightness.dark
              ? Palette.textPrimary
              : Palette.lightInk,
      displayColor:
          brightness == Brightness.dark
              ? Palette.textPrimary
              : Palette.lightInk,
    );
  }
}

/// Extra semantic tokens not covered by [ColorScheme], exposed via a
/// [ThemeExtension] so screens read them with `context.uni.orange`.
@immutable
class UniColors extends ThemeExtension<UniColors> {
  const UniColors({
    required this.orange,
    required this.orangeSoft,
    required this.cyanSoft,
    required this.bubbleIn,
    required this.bubbleOut,
    required this.bubbleOutInk,
    required this.cardElevated,
    required this.input,
    required this.border,
    required this.textSecondary,
    required this.textMuted,
  });

  final Color orange;
  final Color orangeSoft;
  final Color cyanSoft;
  final Color bubbleIn;
  final Color bubbleOut;
  final Color bubbleOutInk;
  final Color cardElevated;
  final Color input;
  final Color border;
  final Color textSecondary;
  final Color textMuted;

  static const dark = UniColors(
    orange: Palette.orange,
    orangeSoft: Palette.orangeSoft,
    cyanSoft: Palette.cyanSoft,
    bubbleIn: Palette.darkBubbleIn,
    bubbleOut: Palette.bubbleOut,
    bubbleOutInk: Palette.textPrimary,
    cardElevated: Palette.darkCard,
    input: Palette.darkCard2,
    border: Palette.darkOutline,
    textSecondary: Palette.darkMuted,
    textMuted: Palette.darkFaint,
  );

  static const light = UniColors(
    orange: Palette.orange,
    orangeSoft: Palette.orangeSoft,
    cyanSoft: Palette.cyanSoft,
    bubbleIn: Palette.lightBubbleIn,
    bubbleOut: Palette.bubbleOutLight,
    bubbleOutInk: Palette.lightInk,
    cardElevated: Palette.lightCard,
    input: Color(0xFFF0F2F3),
    border: Palette.lightOutline,
    textSecondary: Palette.lightMuted,
    textMuted: Palette.lightFaint,
  );

  @override
  UniColors copyWith({
    Color? orange,
    Color? orangeSoft,
    Color? cyanSoft,
    Color? bubbleIn,
    Color? bubbleOut,
    Color? bubbleOutInk,
    Color? cardElevated,
    Color? input,
    Color? border,
    Color? textSecondary,
    Color? textMuted,
  }) {
    return UniColors(
      orange: orange ?? this.orange,
      orangeSoft: orangeSoft ?? this.orangeSoft,
      cyanSoft: cyanSoft ?? this.cyanSoft,
      bubbleIn: bubbleIn ?? this.bubbleIn,
      bubbleOut: bubbleOut ?? this.bubbleOut,
      bubbleOutInk: bubbleOutInk ?? this.bubbleOutInk,
      cardElevated: cardElevated ?? this.cardElevated,
      input: input ?? this.input,
      border: border ?? this.border,
      textSecondary: textSecondary ?? this.textSecondary,
      textMuted: textMuted ?? this.textMuted,
    );
  }

  @override
  UniColors lerp(UniColors? other, double t) {
    if (other == null) return this;
    return UniColors(
      orange: Color.lerp(orange, other.orange, t)!,
      orangeSoft: Color.lerp(orangeSoft, other.orangeSoft, t)!,
      cyanSoft: Color.lerp(cyanSoft, other.cyanSoft, t)!,
      bubbleIn: Color.lerp(bubbleIn, other.bubbleIn, t)!,
      bubbleOut: Color.lerp(bubbleOut, other.bubbleOut, t)!,
      bubbleOutInk: Color.lerp(bubbleOutInk, other.bubbleOutInk, t)!,
      cardElevated: Color.lerp(cardElevated, other.cardElevated, t)!,
      input: Color.lerp(input, other.input, t)!,
      border: Color.lerp(border, other.border, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
    );
  }
}

/// Convenience accessor: `context.uni.bubbleOut`.
extension UniColorsX on BuildContext {
  UniColors get uni => Theme.of(this).extension<UniColors>() ?? UniColors.dark;
}

/// Centralised layout tokens (spacing, radii, sizes, breakpoints).
abstract final class Layout {
  static const double px = 20; // standard horizontal page padding
  static const double pxCompact = 14;
  static const double gap = 8; // 8-point system
  static const double gap2 = 16;
  static const double gap3 = 24;

  static const double rSm = 12;
  static const double rMd = 16;
  static const double rLg = 20;
  static const double rXl = 28;

  static const double avatarSm = 40;
  static const double avatarMd = 52;
  static const double avatarLg = 72;

  static const double buttonH = 52;
  static const double minTouch = 48;
  static const double maxContentWidth = 720; // forms / reading width
  static const double maxBubbleWidth = 560;

  // Breakpoints (logical px)
  static const double bpCompact = 360;
  static const double bpExpanded = 600;
  static const double bpLarge = 840;
  static const double bpWide = 1000; // master-detail threshold

  static bool isCompact(BuildContext c) =>
      MediaQuery.sizeOf(c).width < bpCompact;
  static bool isExpanded(BuildContext c) =>
      MediaQuery.sizeOf(c).width >= bpExpanded;
  static bool isWide(BuildContext c) => MediaQuery.sizeOf(c).width >= bpWide;
}

abstract final class AppTheme {
  /// UniCom is dark-mode-first; [dark] is the default theme.
  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness b) {
    final bool dark = b == Brightness.dark;
    final Color bg = dark ? Palette.bg : Palette.lightBg;
    final Color surface = dark ? Palette.bg2 : Palette.lightSurface;
    final Color cardElev = dark ? Palette.darkCard : Palette.lightCard;

    final ColorScheme scheme = ColorScheme(
      brightness: b,
      primary: Palette.cyan,
      onPrimary: const Color(0xFF00232B),
      primaryContainer: dark ? Palette.cyanSoft : const Color(0xFFD7F4FA),
      onPrimaryContainer: dark ? Palette.cyan : const Color(0xFF07505C),
      secondary: Palette.cyan2,
      onSecondary: const Color(0xFF00232B),
      secondaryContainer: dark ? Palette.cyanSoft : const Color(0xFFD7F4FA),
      onSecondaryContainer: dark ? Palette.cyan : const Color(0xFF07505C),
      tertiary: Palette.orange,
      onTertiary: Colors.white,
      error: Palette.danger,
      onError: Colors.white,
      surface: surface,
      onSurface: dark ? Palette.textPrimary : Palette.lightInk,
      surfaceContainerHighest: cardElev,
      onSurfaceVariant: dark ? Palette.textSecondary : Palette.lightMuted,
      outline: dark ? Palette.border : Palette.lightOutline,
      outlineVariant: dark ? Palette.border : Palette.lightOutline2,
      inverseSurface: dark ? Palette.textPrimary : Palette.lightInk,
      onInverseSurface: dark ? Palette.bg : Palette.lightSurface,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: b,
      colorScheme: scheme,
      extensions: [dark ? UniColors.dark : UniColors.light],
      scaffoldBackgroundColor: bg,
      textTheme: AppType.build(b),
      splashFactory: InkSparkle.splashFactory,
      appBarTheme: AppBarTheme(
        backgroundColor: bg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleSpacing: 0,
        iconTheme: IconThemeData(
          color: dark ? Palette.textPrimary : Palette.lightInk,
        ),
        titleTextStyle: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: dark ? Palette.textPrimary : Palette.lightInk,
          letterSpacing: .1,
        ),
      ),
      dividerTheme: DividerThemeData(
        color: (dark ? Palette.border : Palette.lightOutline).withValues(
          alpha: .9,
        ),
        thickness: .8,
        space: .8,
      ),
      iconTheme: IconThemeData(
        color: dark ? Palette.textSecondary : Palette.lightMuted,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) =>
              states.contains(WidgetState.selected)
                  ? const Color(0xFF00232B)
                  : (dark ? Palette.textMuted : Colors.white),
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) =>
              states.contains(WidgetState.selected)
                  ? Palette.cyan
                  : (dark ? Palette.darkTrack : const Color(0xFFD7DEE4)),
        ),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: dark ? Palette.darkCard : const Color(0xFFF0F2F3),
        selectedColor: dark ? Palette.cyanSoft : const Color(0xFFD7F4FA),
        side: BorderSide(color: dark ? Palette.border : Palette.lightOutline),
        labelStyle: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: dark ? Palette.textSecondary : Palette.lightMuted,
        ),
        shape: const StadiumBorder(),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: dark ? Palette.darkCard2 : Palette.lightInk,
        contentTextStyle: const TextStyle(
          color: Colors.white,
          fontSize: 13.5,
          fontWeight: FontWeight.w500,
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: dark ? Palette.darkSurface : Palette.lightSurface,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: dark ? Palette.darkSurface : Palette.lightSurface,
        showDragHandle: true,
        dragHandleColor: (dark ? Palette.darkOutline : Palette.lightTrack)
            .withValues(alpha: 1),
        dragHandleSize: const Size(44, 4),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: dark ? Palette.darkCard2 : const Color(0xFFF0F2F3),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: Layout.gap2,
          vertical: 13,
        ),
        hintStyle: TextStyle(
          color: dark ? Palette.textMuted : Palette.lightFaint,
          fontWeight: FontWeight.w400,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Layout.rMd),
          borderSide: BorderSide(
            color: dark ? Palette.border : Palette.lightOutline2,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Layout.rMd),
          borderSide: BorderSide(
            color: dark ? Palette.border : Palette.lightOutline2,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Layout.rMd),
          borderSide: const BorderSide(color: Palette.cyan, width: 1.4),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Layout.rMd),
          borderSide: const BorderSide(color: Palette.danger),
        ),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: scheme.onSurfaceVariant,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Layout.rMd),
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: Palette.cyan,
        linearTrackColor: Palette.cyanSoft,
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: Palette.cyan,
        inactiveTrackColor: dark ? Palette.darkTrack : Palette.lightTrack,
        thumbColor: Palette.cyan,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, Layout.buttonH),
          textStyle: const TextStyle(
            fontSize: 15.5,
            fontWeight: FontWeight.w700,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Layout.rXl),
          ),
        ),
      ),
    );
  }
}
