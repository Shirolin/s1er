import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';
import '../utils/window_size.dart';

/// Wraps a page with a persistent [NavigationRail] on medium+ screens.
///
/// On compact screens this is a transparent pass-through. On medium+ it
/// renders the same 4-tab navigation as [HomeScreen] on the left, giving
/// sub-pages (forum list, thread detail, settings, etc.) a consistent
/// desktop shell.
///
/// [highlightedTab] controls which tab appears selected:
/// - 0 = 论坛 (forum / thread pages)
/// - 1 = 搜索
/// - 2 = 消息 (PM pages)
/// - 3 = 我的 (profile / settings / user-space / etc.)
///
/// Tapping a destination opens the corresponding HomeScreen tab.
class S1DesktopScaffold extends ConsumerWidget {
  const S1DesktopScaffold({
    super.key,
    required this.child,
    this.highlightedTab = 0,
  });

  final Widget child;

  /// Index of the tab to show as selected (0-3).
  final int highlightedTab;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!context.isMediumOrAbove) return child;

    final scheme = Theme.of(context).colorScheme;
    final isLoggedIn = ref.watch(
      authStateProvider.select((auth) => auth.isLoggedIn),
    );

    void selectDestination(int index) {
      final tab = isLoggedIn
          ? const ['forum', 'search', 'messages', 'profile'][index]
          : const ['forum', 'profile'][index];
      GoRouter.of(context).go(tab == 'forum' ? '/' : '/?tab=$tab');
    }

    return Row(
      children: [
        NavigationRail(
          selectedIndex: highlightedTab,
          onDestinationSelected: selectDestination,
          labelType: NavigationRailLabelType.all,
          leading: Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 8),
            child: Icon(Icons.forum, size: 28, color: scheme.primary),
          ),
          destinations: isLoggedIn
              ? const [
                  NavigationRailDestination(
                    icon: Icon(Icons.forum),
                    selectedIcon: Icon(Icons.forum),
                    label: Text('论坛'),
                  ),
                  NavigationRailDestination(
                    icon: Icon(Icons.search),
                    selectedIcon: Icon(Icons.search),
                    label: Text('搜索'),
                  ),
                  NavigationRailDestination(
                    icon: Icon(Icons.message),
                    selectedIcon: Icon(Icons.message),
                    label: Text('消息'),
                  ),
                  NavigationRailDestination(
                    icon: Icon(Icons.person),
                    selectedIcon: Icon(Icons.person),
                    label: Text('我的'),
                  ),
                ]
              : const [
                  NavigationRailDestination(
                    icon: Icon(Icons.forum),
                    selectedIcon: Icon(Icons.forum),
                    label: Text('论坛'),
                  ),
                  NavigationRailDestination(
                    icon: Icon(Icons.person),
                    selectedIcon: Icon(Icons.person),
                    label: Text('我的'),
                  ),
                ],
        ),
        VerticalDivider(width: 1, thickness: 1, color: scheme.outlineVariant),
        Expanded(child: child),
      ],
    );
  }
}
