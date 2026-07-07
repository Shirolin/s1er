import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'providers/settings_provider.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'screens/forum_list_screen.dart';
import 'screens/thread_detail_screen.dart';
import 'screens/compose_screen.dart';
import 'screens/profile_screen.dart';
import 'theme/app_theme.dart';

// 使用 final 全局变量，避免每次 rebuild 重新创建
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
      builder: (context, state) => ThreadDetailScreen(
        tid: state.pathParameters['tid']!,
      ),
    ),
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginScreen(),
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

    return MaterialApp.router(
      title: 'S1 Client',
      theme: AppTheme.lightTheme(),
      darkTheme: AppTheme.darkTheme(),
      themeMode: themeMode,
      routerConfig: _router,
    );
  }
}
