import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:s1er/theme/app_theme.dart';
import 'package:s1er/services/api_service.dart';
import 'package:s1er/widgets/s1_error_view.dart';
import 'package:url_launcher/url_launcher.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(
        theme: AppTheme.lightTheme('purple'),
        home: Scaffold(body: child),
      );

  group('S1ErrorView', () {
    testWidgets('维护异常显示扳手图标和论坛原文', (tester) async {
      await tester.pumpWidget(
        wrap(
          S1ErrorView(
            error: ServerMaintenanceException('姨妈一会，太卡了'),
          ),
        ),
      );

      expect(find.byIcon(Icons.build_circle_outlined), findsOneWidget);
      expect(find.text('论坛维护中'), findsOneWidget);
      expect(find.text('姨妈一会，太卡了'), findsOneWidget);
      expect(find.text('请稍后再试'), findsOneWidget);
      expect(find.text('重试'), findsOneWidget);
      expect(find.text('打开网页版论坛'), findsOneWidget);
    });

    testWidgets('维护异常可打开网页版论坛', (tester) async {
      Uri? openedUri;
      await tester.pumpWidget(
        wrap(
          S1ErrorView(
            error: ServerMaintenanceException('姨妈一会，太卡了'),
            forumWebUrl: 'https://stage1st.com/2b',
            forumWebLauncher: (uri, {mode = LaunchMode.platformDefault}) async {
              openedUri = uri;
              return true;
            },
          ),
        ),
      );

      await tester.tap(find.text('打开网页版论坛'));
      await tester.pumpAndSettle();

      expect(openedUri, Uri.parse('https://stage1st.com/2b'));
    });

    testWidgets('登录异常显示锁图标、上游限制说明和去登录按钮', (tester) async {
      var loginTapped = false;
      await tester.pumpWidget(
        wrap(
          S1ErrorView(
            error: LoginRequiredException(),
            onLogin: () => loginTapped = true,
          ),
        ),
      );

      expect(find.byIcon(Icons.lock_outline), findsOneWidget);
      expect(find.text('请先登录'), findsOneWidget);
      expect(find.text('当前 Stage1st 需要登录后查看论坛内容'), findsOneWidget);
      expect(find.text('去登录'), findsOneWidget);

      await tester.tap(find.text('去登录'));
      expect(loginTapped, isTrue);
    });

    testWidgets('通用错误显示红色错误图标和重试按钮', (tester) async {
      var retried = false;
      await tester.pumpWidget(
        wrap(
          S1ErrorView(
            error: Exception('网络超时'),
            onRetry: () => retried = true,
          ),
        ),
      );

      expect(find.byIcon(Icons.error_outline), findsOneWidget);
      expect(find.text('加载失败'), findsOneWidget);
      expect(find.text('重试'), findsOneWidget);

      await tester.tap(find.text('重试'));
      expect(retried, isTrue);
    });

    testWidgets('网络超时显示友好文案而非 DioException 原文', (tester) async {
      await tester.pumpWidget(
        wrap(
          S1ErrorView(
            error: DioException.connectionTimeout(
              timeout: const Duration(seconds: 20),
              requestOptions: RequestOptions(path: '/api/mobile/index.php'),
            ),
          ),
        ),
      );

      expect(find.text('加载失败'), findsOneWidget);
      expect(find.text('连接超时，请检查网络后重试'), findsOneWidget);
      expect(find.textContaining('DioException'), findsNothing);
    });
  });
}
