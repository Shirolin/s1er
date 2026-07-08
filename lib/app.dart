import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:talker_flutter/talker_flutter.dart';
import 'providers/settings_provider.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'screens/forum_list_screen.dart';
import 'screens/thread_detail_screen.dart';
import 'screens/compose_screen.dart';
import 'screens/profile_screen.dart';
import 'theme/app_theme.dart';

GoRouter _createRouter(Talker talker) {
  return GoRouter(
    initialLocation: '/',
    observers: [TalkerRouteObserver(talker)],
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
}

class S1App extends ConsumerStatefulWidget {
  const S1App({super.key, required this.talker});

  final Talker talker;

  @override
  ConsumerState<S1App> createState() => _S1AppState();
}

class _S1AppState extends ConsumerState<S1App> {
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    _router = _createRouter(widget.talker);
  }

  @override
  Widget build(BuildContext context) {
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
