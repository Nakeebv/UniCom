import 'package:flutter/material.dart';

import '../../core/theme/palette.dart';
import '../../core/utils.dart';
import '../../data/demo/avatar_registry.dart';
import '../../data/models/language.dart';
import 'dart:math';

/// Centers content and caps its width — used for auth forms so they don't
/// stretch across tablets / desktop windows.
class MaxWidthBody extends StatelessWidget {
  const MaxWidthBody({
    super.key,
    required this.child,
    this.maxWidth = 480,
    this.padding = const EdgeInsets.symmetric(horizontal: 24),
  });

  final Widget child;
  final double maxWidth;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

/// Profile avatar.
///
/// Rendering priority:
///  1. [imageUrl] — a real uploaded / backend-provided photo.
///  2. [imagePath] — a bundled asset (e.g. `AvatarAssets.forUser(id)`).
///  3. Gradient + initials fallback.
///
/// Photo variants clip to a circle; the initials fallback keeps a soft
/// rounded-square shape used by the design system.
class UserAvatar extends StatelessWidget {
  const UserAvatar({
    super.key,
    required this.name,
    this.gradient,
    this.size = 52,
    this.online = false,
    this.showOnline = true,
    this.heroTag,
    this.flagBadge,
    this.imageUrl,
    this.imagePath,
    this.userId,
    this.circle = true,
  });

  final String name;
  final Gradient? gradient;
  final double size;
  final bool online;
  final bool showOnline;
  final Object? heroTag;
  final String? flagBadge;

  /// Real uploaded avatar — highest priority.
  final String? imageUrl;

  /// Bundled asset path — used for demo placeholders.
  final String? imagePath;

  /// When set, resolves a deterministic placeholder via [AvatarAssets].
  final String? userId;

  /// Whether photo avatars are clipped to a circle (default) or rounded box.
  final bool circle;

  String? get _resolvedAsset => imagePath ?? AvatarAssets.forUser(userId);

  @override
  Widget build(BuildContext context) {
    final fallback = _gradientFallback(context);

    Widget avatar = _photoOrFallback(fallback);
    if (heroTag != null) {
      avatar = Hero(tag: heroTag!, child: avatar);
    }

    return SizedBox(
      width: size + (showOnline ? 6 : 0),
      height: size + 6,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(bottom: 0, left: 0, child: avatar),
          if (showOnline && online)
            Positioned(
              top: -1,
              right: -1,
              child: Container(
                padding: const EdgeInsets.all(2.5),
                decoration: BoxDecoration(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  shape: BoxShape.circle,
                ),
                child: Container(
                  width: size >= 60 ? 13 : 11,
                  height: size >= 60 ? 13 : 11,
                  decoration: BoxDecoration(
                    color: Palette.online,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Theme.of(context).scaffoldBackgroundColor,
                      width: 1.6,
                    ),
                  ),
                ),
              ),
            ),
          if (flagBadge != null)
            Positioned(
              bottom: -2,
              right: flagBadge == null ? 0 : -4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(flagBadge!, style: const TextStyle(fontSize: 11)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _photoOrFallback(Widget fallback) {
    final borderRadius = BorderRadius.circular(circle ? size / 2 : size * 0.32);
    final asset = _resolvedAsset;

    if (imageUrl != null && imageUrl!.isNotEmpty) {
      return ClipRRect(
        borderRadius: borderRadius,
        child: Image.network(
          imageUrl!,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => fallback,
          loadingBuilder: (context, child, progress) {
            if (progress == null) return child;
            return _skeleton(borderRadius);
          },
        ),
      );
    }
    if (asset != null) {
      return ClipRRect(
        borderRadius: borderRadius,
        child: Image.asset(
          asset,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => fallback,
        ),
      );
    }
    return fallback;
  }

  Widget _skeleton(BorderRadius borderRadius) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        color: const Color(0xFF1B2A2D),
      ),
    );
  }

  Widget _gradientFallback(BuildContext context) {
    final br = BorderRadius.circular(circle ? size / 2 : size * 0.32);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: gradient ?? Palette.brand,
        borderRadius: br,
      ),
      child: Center(
        child: Text(
          initialsOf(name),
          style: TextStyle(
            color: Colors.white,
            fontSize: size * 0.34,
            fontWeight: FontWeight.w700,
            letterSpacing: .3,
          ),
        ),
      ),
    );
  }
}

/// Rounded capsule chip with optional icon — used for language pairs,
/// capabilities, statuses.
class Capsule extends StatelessWidget {
  const Capsule({
    super.key,
    required this.label,
    this.icon,
    this.foreground,
    this.background,
    this.borderColor,
    this.fontSize = 11.5,
    this.padding = const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
  });

  final String label;
  final IconData? icon;
  final Color? foreground;
  final Color? background;
  final Color? borderColor;
  final double fontSize;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fg = foreground ?? scheme.onSurfaceVariant;
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: background ?? scheme.onSurfaceVariant.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(999),
        border:
            borderColor == null
                ? null
                : Border.all(color: borderColor!, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: fontSize + 2.5, color: fg),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              color: fg,
              fontSize: fontSize,
              fontWeight: FontWeight.w600,
              letterSpacing: .1,
            ),
          ),
        ],
      ),
    );
  }
}

/// "🇪🇸 Español → 🇳🇬 Yorùbá" pipeline chip used across chat + list tiles.
class LanguageRouteChip extends StatelessWidget {
  const LanguageRouteChip({
    super.key,
    required this.from,
    required this.to,
    this.compact = false,
  });

  final LanguageInfo from;
  final LanguageInfo to;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return Capsule(label: '${from.code} → ${to.code}');
    }
    return Capsule(
      icon: Icons.translate_rounded,
      label: '${from.nativeName} → ${to.nativeName}',
      background: Palette.iris.withValues(alpha: .1),
      foreground: Palette.irisDark,
    );
  }
}

/// Soft filled button with optional gradient & loading state.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.expand = true,
    this.loading = false,
    this.danger = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool expand;
  final bool loading;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !loading;
    return Opacity(
      opacity: enabled ? 1 : .55,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: danger ? null : (enabled ? Palette.brand : null),
          color:
              danger
                  ? Theme.of(context).colorScheme.error
                  : (enabled ? null : Theme.of(context).colorScheme.outline),
          borderRadius: BorderRadius.circular(16),
          boxShadow:
              enabled && !danger
                  ? [
                    BoxShadow(
                      color: Palette.iris.withValues(alpha: .35),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ]
                  : null,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: enabled ? onPressed : null,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              height: 54,
              padding: const EdgeInsets.symmetric(horizontal: 22),
              alignment: Alignment.center,
              child: Row(
                mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (loading)
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        valueColor: AlwaysStoppedAnimation(Colors.white),
                      ),
                    )
                  else ...[
                    if (icon != null) ...[
                      Icon(icon, color: Colors.white, size: 20),
                      const SizedBox(width: 9),
                    ],
                    Text(
                      label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 15.5,
                        letterSpacing: .2,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Text button styled as subtle pill.
class GhostButton extends StatelessWidget {
  const GhostButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.danger = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: danger ? scheme.error : scheme.primary,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 18), const SizedBox(width: 6)],
          Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

/// Labeled input used across auth + settings forms.
class UniField extends StatelessWidget {
  const UniField({
    super.key,
    required this.controller,
    required this.hint,
    this.label,
    this.icon,
    this.obscure = false,
    this.keyboardType,
    this.validator,
    this.suffix,
    this.focusNode,
    this.onChanged,
    this.prefix,
  });

  final TextEditingController controller;
  final String hint;
  final String? label;
  final IconData? icon;
  final bool obscure;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final Widget? suffix;
  final Widget? prefix;
  final FocusNode? focusNode;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null) ...[
          Padding(
            padding: const EdgeInsets.only(left: 6, bottom: 7),
            child: Text(
              label!,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
        TextFormField(
          controller: controller,
          focusNode: focusNode,
          obscureText: obscure,
          keyboardType: keyboardType,
          validator: validator,
          onChanged: onChanged,
          style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 15),
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon:
                icon != null
                    ? Icon(
                      icon,
                      size: 20,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    )
                    : prefix,
            suffixIcon: suffix,
          ),
        ),
      ],
    );
  }
}

/// Aligns a section header + optional action.
class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.action});
  final String title;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 22, 12, 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title.toUpperCase(),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.1,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          if (action != null) action!,
        ],
      ),
    );
  }
}

/// Shimmer placeholder used by the "Translating…" state.
class ShimmerBox extends StatelessWidget {
  const ShimmerBox({
    super.key,
    this.width = 140,
    this.height = 12,
    this.radius = 7,
  });

  final double width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final base = (dark ? Colors.white : Colors.black).withValues(
      alpha: dark ? .09 : .07,
    );
    final hi = (dark ? Colors.white : Colors.black).withValues(
      alpha: dark ? .18 : .13,
    );
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 1150),
      curve: Curves.linear,
      builder: (context, t, _) {
        return Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            gradient: LinearGradient(
              begin: Alignment(-1 + 2 * t, 0),
              end: Alignment(0 + 2 * t, 0),
              colors: [base, hi, base],
            ),
          ),
        );
      },
      onEnd: () {},
    );
  }
}

/// Bouncing triple dots (typing indicator).
class TypingDots extends StatefulWidget {
  const TypingDots({super.key, this.color, this.size = 7});
  final Color? color;
  final double size;

  @override
  State<TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<TypingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1050),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color =
        widget.color ??
        Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: .8);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (i) {
        return AnimatedBuilder(
          animation: _c,
          builder: (context, _) {
            final phase = (_c.value * 3 - i).clamp(0.0, 1.0);
            final lift = sin(phase * pi);
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Transform.translate(
                offset: Offset(0, -3.2 * lift),
                child: Container(
                  width: widget.size,
                  height: widget.size,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: .35 + .65 * lift),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            );
          },
        );
      }),
    );
  }
}

/// Unread count badge.
class UnreadBadge extends StatelessWidget {
  const UnreadBadge(this.count, {super.key});
  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 22),
      height: 22,
      padding: const EdgeInsets.symmetric(horizontal: 7),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: Palette.brand,
        borderRadius: BorderRadius.circular(999),
        boxShadow: [
          BoxShadow(
            color: Palette.iris.withValues(alpha: .4),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Text(
        count > 99 ? '99+' : '$count',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11.5,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

/// Empty-state panel with illustration glyph.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.action,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 86,
              height: 86,
              decoration: BoxDecoration(
                gradient: Palette.brandSoft,
                shape: BoxShape.circle,
                border: Border.all(color: scheme.outline.withValues(alpha: .6)),
              ),
              child: Icon(icon, size: 38, color: Palette.iris),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13.5,
                color: scheme.onSurfaceVariant,
                height: 1.45,
              ),
            ),
            if (action != null) ...[const SizedBox(height: 18), action!],
          ],
        ),
      ),
    );
  }
}
