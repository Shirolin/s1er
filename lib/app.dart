import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:talker_flutter/talker_flutter.dart';
import 'config/resource_domains.dart';
import 'providers/reading_history_coordinator.dart';
import 'providers/settings_provider.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'screens/forum_list_screen.dart';
import 'screens/thread_detail_screen.dart';
import 'screens/compose_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/reading_history_screen.dart';
import 'screens/blacklist_screen.dart';
import 'screens/favorites_screen.dart';
import 'screens/friends_screen.dart';
import 'screens/dark_room_screen.dart';
import 'screens/image_viewer_screen.dart';
import 'screens/user_space_screen.dart';
import 'screens/pm_conversation_screen.dart';
import 'providers/thread_open_intent_provider.dart';
import 'services/talker.dart';
import 'theme/app_theme.dart';
import 'utils/thread_navigation.dart';

ImageViewerScreen? _parseImageViewerRoute(GoRouterState state) {
  Map<String, dynamic>? args;
  if (state.extra is Map<String, dynamic>) {
    args = state.extra! as Map<String, dynamic>;
  }

  final urlFromQuery = state.uri.queryParameters['url'];
  final fullFromQuery = state.uri.queryParameters['fullUrl'];
  final imageUrl =
      args?['imageUrl'] as String? ?? fullFromQuery ?? urlFromQuery;
  if (imageUrl == null || imageUrl.isEmpty) return null;

  final typeStr =
      state.uri.queryParameters['type'] ?? args?['resourceType']?.toString();
  ResourceType resourceType = ResourceType.publicAsset;
  if (typeStr != null) {
    resourceType = ResourceType.values.firstWhere(
      (t) => t.name == typeStr,
      orElse: () => ResourceType.publicAsset,
    );
  } else if (args?['resourceType'] is ResourceType) {
    resourceType = args!['resourceType'] as ResourceType;
  }

  return ImageViewerScreen(
    imageUrl: imageUrl,
    imageBytes: args?['imageBytes'] as Uint8List?,
    resourceType: resourceType,
  );
}

final _router = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(path: '/', builder: (context, state) => const HomeScreen()),
    GoRoute(
      path: '/forum/:fid',
      builder: (context, state) =>
          ForumListScreen(fid: state.pathParameters['fid']!),
    ),
    GoRoute(
      path: '/thread/:tid',
      // Key only by tid so in-thread `?page=` replace syncs URL without remount.
      pageBuilder: (context, state) {
        final tid = state.pathParameters['tid']!;
        final intent = ThreadRouteCodec.intentFromUri(state.uri, tid: tid);
        return NoTransitionPage<void>(
          key: ValueKey('thread-$tid'),
          child: ProviderScope(
            overrides: [
              threadOpenIntentProvider(tid).overrideWithValue(intent),
            ],
            child: ThreadDetailScreen(tid: tid),
          ),
        );
      },
    ),
    GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
    GoRoute(
      path: '/pm/:touid',
      builder: (context, state) => PmConversationScreen(
        touid: state.pathParameters['touid']!,
        partnerName: state.uri.queryParameters['name'],
      ),
    ),
    GoRoute(
      path: '/compose',
      builder: (context, state) => ComposeScreen(
        tid: state.uri.queryParameters['tid'],
        fid: state.uri.queryParameters['fid'],
        draftId: state.uri.queryParameters['draftId'],
        reppost: state.uri.queryParameters['reppost'],
        subject: state.uri.queryParameters['subject'],
      ),
    ),
    GoRoute(
      path: '/forum/:fid/new-thread',
      builder: (context, state) => ComposeScreen(
        fid: state.pathParameters['fid'],
        newThread: true,
      ),
    ),
    GoRoute(
      path: '/profile',
      builder: (context, state) => const ProfileScreen(),
    ),
    GoRoute(
      path: '/settings',
      builder: (context, state) => const SettingsScreen(),
    ),
    GoRoute(
      path: '/reading-history',
      builder: (context, state) => const ReadingHistoryScreen(),
    ),
    GoRoute(
      path: '/blacklist',
      builder: (context, state) => const BlacklistScreen(),
    ),
    GoRoute(
      path: '/favorites',
      builder: (context, state) => const FavoritesScreen(),
    ),
    GoRoute(
      path: '/friends',
      builder: (context, state) => const FriendsScreen(),
    ),
    GoRoute(
      path: '/dark-room',
      builder: (context, state) => const DarkRoomScreen(),
    ),
    GoRoute(
      path: '/user-space/:uid',
      builder: (context, state) => UserSpaceScreen(
        uid: state.pathParameters['uid']!,
        username: state.uri.queryParameters['username'],
        initialTab: int.tryParse(state.uri.queryParameters['tab'] ?? '') ?? 0,
        isSelf: state.uri.queryParameters['self'] == '1',
      ),
    ),
    GoRoute(
      path: '/image-viewer',
      builder: (context, state) {
        final screen = _parseImageViewerRoute(state);
        if (screen != null) return screen;
        return Scaffold(
          appBar: AppBar(elevation: 0, title: const Text('图片')),
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('无法加载图片'),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => context.pop(),
                  child: const Text('返回'),
                ),
              ],
            ),
          ),
        );
      },
    ),
  ],
);

class S1App extends ConsumerStatefulWidget {
  const S1App({super.key});

  @override
  ConsumerState<S1App> createState() => _S1AppState();
}

class _S1AppState extends ConsumerState<S1App> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      unawaited(ref.read(localDataProvider).flushPendingWrites());
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(readingHistoryCoordinatorProvider);

    final themeModeStr = ref.watch(settingsProvider.select((s) => s.themeMode));
    final themeColor = ref.watch(settingsProvider.select((s) => s.themeColor));
    final textScaleFactor = ref.watch(
      settingsProvider.select((s) => s.textScaleFactor),
    );

    final themeMode = switch (themeModeStr) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };

    return TalkerWrapper(
      talker: talker,
      options: const TalkerWrapperOptions(enableErrorAlerts: true),
      child: MaterialApp.router(
        title: 'S1 Client',
        theme: AppTheme.lightTheme(themeColor),
        darkTheme: AppTheme.darkTheme(themeColor),
        themeMode: themeMode,
        routerConfig: _router,
        builder: (context, child) {
          return MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(textScaleFactor)),
            child: child!,
          );
        },
      ),
    );
  }
}
