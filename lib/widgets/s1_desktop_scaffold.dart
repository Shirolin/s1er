import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';
import '../providers/unread_count_provider.dart';
import '../theme/s1_haptics.dart';
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
    final unreadTotal = isLoggedIn
        ? ref.watch(unreadCountProvider.select((c) => c.total))
        : 0;
    final unreadDisplay = isLoggedIn
        ? ref.watch(unreadCountProvider.select((c) => c.displayBadge))
        : '';

    void selectDestination(int index) {
      S1Haptics.selection();
      final tab = isLoggedIn
          ? const ['forum', 'search', 'messages', 'profile'][index]
          : const ['forum', 'profile'][index];
      GoRouter.of(context).go(tab == 'forum' ? '/' : '/?tab=$tab');
    }

    bool acceptsGlobalShortcut() {
      final focusContext = FocusManager.instance.primaryFocus?.context;
      return focusContext == null ||
          (focusContext.widget is! EditableText &&
              focusContext.findAncestorWidgetOfExactType<EditableText>() ==
                  null);
    }

    void selectDestinationByShortcut(int index) {
      if (acceptsGlobalShortcut()) selectDestination(index);
    }

    // Logged-out rail only has 论坛/我的; map the semantic tab index (0-3)
    // to the reduced destination list, unselect tabs that don't exist.
    final selectedIndex = isLoggedIn
        ? highlightedTab
        : switch (highlightedTab) { 0 => 0, 3 => 1, _ => null };

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.digit1, alt: true): () =>
            selectDestinationByShortcut(0),
        if (isLoggedIn) ...{
          const SingleActivator(LogicalKeyboardKey.digit2, alt: true): () =>
              selectDestinationByShortcut(1),
          const SingleActivator(LogicalKeyboardKey.digit3, alt: true): () =>
              selectDestinationByShortcut(2),
          const SingleActivator(LogicalKeyboardKey.digit4, alt: true): () =>
              selectDestinationByShortcut(3),
        } else
          const SingleActivator(LogicalKeyboardKey.digit2, alt: true): () =>
              selectDestinationByShortcut(1),
      },
      child: Focus(
        autofocus: true,
        child: Row(
          children: [
            NavigationRail(
              selectedIndex: selectedIndex,
              onDestinationSelected: selectDestination,
              labelType: NavigationRailLabelType.all,
              leading: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: IconButton(
                  tooltip: '首页',
                  onPressed: () => GoRouter.of(context).go('/'),
                  icon: Image.asset(
                    'assets/branding/s1er_mark.png',
                    width: 28,
                    height: 28,
                    color: scheme.primary,
                    colorBlendMode: BlendMode.srcIn,
                    filterQuality: FilterQuality.medium,
                    gaplessPlayback: true,
                    excludeFromSemantics: true,
                  ),
                ),
              ),
              destinations: isLoggedIn
                  ? [
                      const NavigationRailDestination(
                        icon: Icon(Icons.forum),
                        selectedIcon: Icon(Icons.forum),
                        label: Text('论坛'),
                      ),
                      const NavigationRailDestination(
                        icon: Icon(Icons.search),
                        selectedIcon: Icon(Icons.search),
                        label: Text('搜索'),
                      ),
                      NavigationRailDestination(
                        icon: Badge(
                          label: Text(unreadDisplay),
                          isLabelVisible: unreadTotal > 0,
                          child: const Icon(Icons.message),
                        ),
                        selectedIcon: Badge(
                          label: Text(unreadDisplay),
                          isLabelVisible: unreadTotal > 0,
                          child: const Icon(Icons.message),
                        ),
                        label: const Text('消息'),
                      ),
                      const NavigationRailDestination(
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
            Expanded(child: child),
          ],
        ),
      ),
    );
  }
}
