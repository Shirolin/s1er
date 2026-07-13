import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:s1_app/providers/auth_provider.dart';
import 'package:s1_app/screens/login_screen.dart';
import 'package:s1_app/theme/app_theme.dart';

void main() {
  testWidgets('LoginScreen renders username, password and login button',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateProvider.overrideWith(_LoggedOutAuthNotifier.new),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme('purple'),
          home: const LoginScreen(),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('欢迎回来'), findsOneWidget);
    expect(find.text('登录您的 Stage1st 账号'), findsOneWidget);
    expect(find.widgetWithText(TextField, '用户名'), findsOneWidget);
    expect(find.widgetWithText(TextField, '密码'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, '登录'), findsOneWidget);
  });

  testWidgets('LoginScreen shows validation error when fields are empty',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateProvider.overrideWith(_LoggedOutAuthNotifier.new),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme('purple'),
          home: const LoginScreen(),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.widgetWithText(FilledButton, '登录'));
    await tester.pump();

    expect(find.text('用户名和密码不能为空'), findsOneWidget);
  });

  testWidgets('LoginScreen navigates home after successful login',
      (tester) async {
    final router = GoRouter(
      initialLocation: '/login',
      routes: [
        GoRoute(
          path: '/login',
          builder: (context, state) => const LoginScreen(),
        ),
        GoRoute(
          path: '/',
          builder: (context, state) => const Scaffold(
            body: Center(child: Text('Home Page')),
          ),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateProvider.overrideWith(_SuccessfulLoginAuthNotifier.new),
        ],
        child: MaterialApp.router(
          theme: AppTheme.lightTheme('purple'),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextField, '用户名'), 'alice');
    await tester.enterText(find.widgetWithText(TextField, '密码'), 'secret');
    await tester.tap(find.widgetWithText(FilledButton, '登录'));
    await tester.pumpAndSettle();

    expect(find.text('Home Page'), findsOneWidget);
  });
}

class _LoggedOutAuthNotifier extends AuthNotifier {
  @override
  AuthState build() => AuthState();
}

class _SuccessfulLoginAuthNotifier extends AuthNotifier {
  @override
  AuthState build() => AuthState();

  @override
  Future<String?> login(String username, String password) async {
    return null;
  }
}
