import 'package:flutter/material.dart';

import '../../core/theme/palette.dart';
import '../../core/theme/theme.dart';

/// Content page chrome shared by Calls / Contacts / Settings:
/// a quiet near-black header (leading · title · trailing) above a dark
/// elevated content surface. The bottom navigation lives in the shell.
class KitPage extends StatelessWidget {
  const KitPage({
    super.key,
    this.leading,
    this.trailing,
    required this.title,
    this.headerExtra,
    this.sheetChildren,
    this.sheetSlivers,
    this.onLeading,
    this.headerHeight = 84,
    this.showHandle = false,
  });

  final Widget? leading;
  final Widget? trailing;
  final String title;

  /// Extra header content rendered under the title row (stories, etc.).
  final Widget? headerExtra;
  final List<Widget>? sheetChildren;
  final List<Widget>? sheetSlivers;
  final VoidCallback? onLeading;
  final double headerHeight;
  final bool showHandle;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final bg = Theme.of(context).scaffoldBackgroundColor;
    final headerColor = dark ? Palette.bg : Palette.lightSurface;

    Widget header = Material(
      color: headerColor,
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                Layout.isCompact(context) ? 8 : 10,
                6,
                12,
                6,
              ),
              child: Row(
                children: [
                  if (leading != null)
                    Semantics(
                      button: true,
                      label: title,
                      child: Material(
                        color:
                            dark
                                ? Palette.darkCard
                                : Colors.black.withValues(alpha: .04),
                        shape: const CircleBorder(),
                        child: InkWell(
                          onTap: onLeading,
                          customBorder: const CircleBorder(),
                          child: SizedBox(
                            width: 44,
                            height: 44,
                            child: IconTheme.merge(
                              data: IconThemeData(
                                color:
                                    dark
                                        ? Palette.textPrimary
                                        : Palette.lightInk,
                                size: 22,
                              ),
                              child: Center(child: leading!),
                            ),
                          ),
                        ),
                      ),
                    )
                  else
                    const SizedBox(width: 44),
                  Expanded(
                    child: Center(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Palette.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -.2,
                        ),
                      ),
                    ),
                  ),
                  if (trailing != null)
                    trailing!
                  else
                    const SizedBox(width: 44),
                ],
              ),
            ),
            if (headerExtra != null) headerExtra!,
          ],
        ),
      ),
    );

    final Widget content =
        sheetSlivers != null
            ? CustomScrollView(slivers: sheetSlivers!)
            : sheetChildren == null
            ? const SizedBox.shrink()
            : Column(children: sheetChildren!);

    final Widget sheet = Material(
      color: bg,
      child: Container(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color: dark ? Palette.border : Palette.lightOutline,
            ),
          ),
        ),
        child: Column(
          children: [
            if (showHandle)
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 10),
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: dark ? Palette.darkOutline : Palette.lightTrack,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: Layout.maxContentWidth,
                  ),
                  child: content,
                ),
              ),
            ),
          ],
        ),
      ),
    );

    return Scaffold(
      backgroundColor: bg,
      body: Column(children: [header, Expanded(child: sheet)]),
    );
  }
}

/// Circular pale-teal icon badge used in Settings/Sheets rows.
class KitIconBadge extends StatelessWidget {
  const KitIconBadge({
    super.key,
    required this.icon,
    this.color,
    this.onTap,
    this.size = 46,
  });

  final IconData icon;
  final Color? color;
  final VoidCallback? onTap;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = color ?? Palette.iris;
    final dark = Theme.of(context).brightness == Brightness.dark;
    Widget core = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color:
            dark
                ? Colors.white.withValues(alpha: .06)
                : c.withValues(alpha: .1),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, size: size * .42, color: c),
    );
    if (onTap == null) return core;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: core,
      ),
    );
  }
}

/// The drag-handle dot row inside sheets (Share Content, etc.).
class SheetHandle extends StatelessWidget {
  const SheetHandle({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 10),
        width: 44,
        height: 4,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: .5),
          borderRadius: BorderRadius.circular(4),
        ),
      ),
    );
  }
}
