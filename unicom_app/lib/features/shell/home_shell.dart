import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/palette.dart';
import '../../core/theme/theme.dart';
import '../../providers.dart';

/// App navigation shell — UniCom dark-neon design.
///
/// Compact / standard phones get a compact bottom bar (cyan active state,
/// unread badge). Expanded widths (≥600px, e.g. tablets / desktop windows)
/// get a [NavigationRail] on the left so the conversation space isn't
/// stretched and the bar doesn't dominate the layout.
class HomeShell extends ConsumerWidget {
  const HomeShell({super.key, required this.child, required this.index});

  final Widget child;
  final int index;

  static const _items = [
    (Icons.chat_bubble_rounded, Icons.chat_bubble_outline_rounded, 'Messages'),
    (Icons.call_rounded, Icons.call_outlined, 'Calls'),
    (Icons.people_rounded, Icons.people_outline_rounded, 'Contacts'),
    (Icons.settings_rounded, Icons.settings_outlined, 'Settings'),
  ];

  static const _dests = ['/chats', '/calls', '/contacts', '/settings'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final barColor = dark ? Palette.bg2 : Palette.lightSurface;
    final wide = Layout.isExpanded(context);
    final unread = ref.watch(backendProvider).totalUnread;

    if (wide) {
      return Scaffold(
        backgroundColor: barColor,
        body: SafeArea(
          child: Row(
            children: [
              NavigationRail(
                backgroundColor: barColor,
                selectedIndex: index,
                onDestinationSelected: (i) => context.go(_dests[i]),
                labelType: NavigationRailLabelType.all,
                indicatorColor: Palette.cyanSoft,
                selectedIconTheme: const IconThemeData(
                  color: Palette.cyan,
                  size: 24,
                ),
                unselectedIconTheme: const IconThemeData(
                  color: Palette.textMuted,
                  size: 24,
                ),
                selectedLabelTextStyle: const TextStyle(
                  color: Palette.cyan,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
                unselectedLabelTextStyle: TextStyle(
                  color: dark ? Palette.textMuted : Palette.lightMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
                leading: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Icon(
                    Icons.translate_rounded,
                    color: Palette.cyan,
                    size: 26,
                  ),
                ),
                destinations: [
                  for (var i = 0; i < _items.length; i++)
                    NavigationRailDestination(
                      icon: _railIcon(i, unread, active: false),
                      selectedIcon: _railIcon(i, unread, active: true),
                      label: Text(_items[i].$3),
                    ),
                ],
              ),
              VerticalDivider(
                width: 1,
                thickness: 1,
                color: dark ? Palette.border : Palette.lightOutline,
              ),
              Expanded(child: child),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: child,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: barColor,
          border: Border(
            top: BorderSide(
              color: dark ? Palette.border : Palette.lightOutline,
            ),
          ),
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(height: 64, child: _bar(context, unread)),
        ),
      ),
    );
  }

  Widget _railIcon(int i, int unread, {required bool active}) {
    final (filled, outlined, _) = _items[i];
    final icon = Icon(active ? filled : outlined);
    if (i != 0 || unread == 0) return icon;
    return Badge(
      label: Text(unread > 99 ? '99+' : '$unread'),
      backgroundColor: Palette.orange,
      child: icon,
    );
  }

  Widget _bar(BuildContext context, int unread) {
    return Row(
      children: List.generate(_items.length, (i) {
        final (filled, outlined, label) = _items[i];
        final active = i == index;
        final ink =
            active
                ? Palette.cyan
                : (Theme.of(context).brightness == Brightness.dark
                    ? Palette.textMuted
                    : Palette.lightMuted);
        return Expanded(
          child: Semantics(
            button: true,
            selected: active,
            label: label,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => context.go(_dests[i]),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (i == 0)
                      _unreadAwareIcon(
                        icon: active ? filled : outlined,
                        color: ink,
                        unread: unread,
                      )
                    else
                      Icon(active ? filled : outlined, size: 23, color: ink),
                    const SizedBox(height: 3),
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                        color: ink,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _unreadAwareIcon({
    required IconData icon,
    required Color color,
    required int unread,
  }) {
    return SizedBox(
      width: 24,
      height: 24,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          Icon(icon, size: 23, color: color),
          if (unread > 0)
            Positioned(
              right: -6,
              top: -4,
              child: Container(
                constraints: const BoxConstraints(minWidth: 16),
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: Palette.orange,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  unread > 99 ? '99+' : '$unread',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
