import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:s1_app/services/api_service.dart';
import 'package:s1_app/widgets/s1_error_view.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(
        home: Scaffold(body: child),
      );

  group('S1ErrorView', () {
    testWidgets('维护异常显示扳手图标和论坛原文', (tester) async {
      await tester.pumpWidget(wrap(
        S1ErrorView(
          error: ServerMaintenanceException('姨妈一会，太卡了'),
        ),
      ),);

      expect(find.byIcon(Icons.build_circle_outlined), findsOneWidget);
      expect(find.text('论坛维护中'), findsOneWidget);
      expect(find.text('姨妈一会，太卡了'), findsOneWidget);
      expect(find.text('请稍后再试'), findsOneWidget);
      expect(find.text('重试'), findsOneWidget);
    });

    testWidgets('登录异常显示锁图标和去登录按钮', (tester) async {
      var loginTapped = false;
      await tester.pumpWidget(wrap(
        S1ErrorView(
          error: LoginRequiredException(),
          onLogin: () => loginTapped = true,
        ),
      ),);

      expect(find.byIcon(Icons.lock_outline), findsOneWidget);
      expect(find.text('请先登录'), findsOneWidget);
      expect(find.text('去登录'), findsOneWidget);

      await tester.tap(find.text('去登录'));
      expect(loginTapped, isTrue);
    });

    testWidgets('通用错误显示红色错误图标和重试按钮', (tester) async {
      var retried = false;
      await tester.pumpWidget(wrap(
        S1ErrorView(
          error: Exception('网络超时'),
          onRetry: () => retried = true,
        ),
      ),);

      expect(find.byIcon(Icons.error_outline), findsOneWidget);
      expect(find.text('加载失败'), findsOneWidget);
      expect(find.text('重试'), findsOneWidget);

      await tester.tap(find.text('重试'));
      expect(retried, isTrue);
    });
  });
}
