import 'dart:typed_data';

import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:talker_flutter/talker_flutter.dart';
import 'config/resource_domains.dart';
import 'providers/settings_provider.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'screens/login_webview_screen.dart';
import 'screens/forum_list_screen.dart';
import 'screens/thread_detail_screen.dart';
import 'screens/compose_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/reading_history_screen.dart';
import 'screens/image_viewer_screen.dart';
import 'services/talker.dart';
import 'theme/app_theme.dart';

ImageViewerScreen? _parseImageViewerRoute(GoRouterState state) {
  Map<String, dynamic>? args;
  if (state.extra is Map<String, dynamic>) {
    args = state.extra! as Map<String, dynamic>;
  }

  final urlFromQuery = state.uri.queryParameters['url'];
  final imageUrl = args?['imageUrl'] as String? ?? urlFromQuery;
  if (imageUrl == null || imageUrl.isEmpty) return null;

  final typeStr = state.uri.queryParameters['type'] ??
      args?['resourceType']?.toString();
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
    GoRoute(
      path: '/',
      builder: (context, state) => const HomeScreen(),
    ),
    GoRoute(
      path: '/forum/:fid',
      builder: (context, state) => ForumListScreen(
        fid: state.pathParameters['fid']!,
      ),
    ),
    GoRoute(
      path: '/thread/:tid',
      builder: (context, state) {
        final pageStr = state.uri.queryParameters['page'];
        final page = pageStr != null ? int.tryParse(pageStr) : null;
        return ThreadDetailScreen(
          tid: state.pathParameters['tid']!,
          initialPage: page,
        );
      },
    ),
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: '/login-webview',
      builder: (context, state) => const LoginWebViewScreen(),
    ),
    GoRoute(
      path: '/compose',
      builder: (context, state) => ComposeScreen(
        tid: state.uri.queryParameters['tid'],
        fid: state.uri.queryParameters['fid'],
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
      path: '/image-viewer',
      builder: (context, state) {
        final screen = _parseImageViewerRoute(state);
        if (screen != null) return screen;
        return Scaffold(
          appBar: AppBar(title: const Text('图片')),
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

class S1App extends ConsumerWidget {
  const S1App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final themeMode = switch (settings.themeMode) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };

    return DynamicColorBuilder(
      builder: (lightDynamic, darkDynamic) {
        final useDynamic = settings.useDynamicColor;
        final hasDynamic = lightDynamic != null && darkDynamic != null;

        final lightTheme = useDynamic && hasDynamic
            ? AppTheme.fromColorScheme(lightDynamic)
            : AppTheme.lightTheme(settings.themeColor);
        final darkTheme = useDynamic && hasDynamic
            ? AppTheme.fromColorScheme(darkDynamic)
            : AppTheme.darkTheme(settings.themeColor);

        return TalkerWrapper(
          talker: talker,
          options: const TalkerWrapperOptions(
            enableErrorAlerts: true,
          ),
          child: MaterialApp.router(
            title: 'S1 Client',
            theme: lightTheme,
            darkTheme: darkTheme,
            themeMode: themeMode,
            routerConfig: _router,
            builder: (context, child) {
              return MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: TextScaler.linear(settings.textScaleFactor),
                ),
                child: child!,
              );
            },
          ),
        );
      },
    );
  }
}
