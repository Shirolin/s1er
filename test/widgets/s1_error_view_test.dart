import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:s1er/theme/app_theme.dart';
import 'package:s1er/models/app_exceptions.dart';
import 'package:s1er/widgets/s1_error_view.dart';
import 'package:url_launcher/url_launcher.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(
        theme: AppTheme.lightTheme('purple'),
        home: Scaffold(body: child),
      );

  group('S1ErrorView', () {
    testWidgets('5xx 主文案保持友好，详情默认折叠', (tester) async {
      await tester.pumpWidget(
        wrap(
          S1ErrorView(
            error: DioException(
              requestOptions: RequestOptions(path: '/x'),
              response: Response(
                requestOptions: RequestOptions(path: '/x'),
                statusCode: 503,
              ),
              error: const ServerBusyException(
                statusCode: 503,
                detail: 'in_array(): Argument #2 must be of type array',
              ),
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.error_outline), findsOneWidget);
      expect(find.text('加载失败'), findsOneWidget);
      // 用户可见文案不暴露服务端实现细节。
      expect(find.text('服务器暂时不可用，请稍后再试'), findsOneWidget);
      expect(
        find.text('in_array(): Argument #2 must be of type array'),
        findsNothing,
      );

      // 默认折叠；展开后才出现技术细节。
      expect(find.text('查看详情'), findsOneWidget);
      await tester.tap(find.text('查看详情'));
      await tester.pumpAndSettle();

      expect(find.text('收起详情'), findsOneWidget);
      expect(
        find.textContaining('HTTP 503'),
        findsOneWidget,
      );
      expect(
        find.textContaining('in_array(): Argument #2'),
        findsOneWidget,
      );
    });

    testWidgets('5xx 带响应体摘要时详情可展开', (tester) async {
      await tester.pumpWidget(
        wrap(
          S1ErrorView(
            error: DioException(
              requestOptions: RequestOptions(path: '/x'),
              response: Response(
                requestOptions: RequestOptions(path: '/x'),
                statusCode: 503,
              ),
              error: const ServerBusyException(
                statusCode: 503,
                detail: 'stage1st.com - System Error',
              ),
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.error_outline), findsOneWidget);
      expect(find.text('加载失败'), findsOneWidget);
      expect(find.text('服务器暂时不可用，请稍后再试'), findsOneWidget);
      expect(find.textContaining('stage1st.com - System Error'), findsNothing);

      await tester.tap(find.text('查看详情'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('stage1st.com - System Error'),
        findsOneWidget,
      );
    });

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

    testWidgets('DioException 包装的维护公告展示官方原文', (tester) async {
      final wrapped = DioException(
        requestOptions: RequestOptions(path: '/2b/api/mobile/index.php'),
        type: DioExceptionType.badResponse,
        error: ServerMaintenanceException('维护公告 \n \n 又被爬了'),
      );
      await tester.pumpWidget(wrap(S1ErrorView(error: wrapped)));

      expect(find.byIcon(Icons.build_circle_outlined), findsOneWidget);
      expect(find.text('论坛维护中'), findsOneWidget);
      expect(find.text('维护公告 \n \n 又被爬了'), findsOneWidget);
      expect(find.text('请稍后再试'), findsOneWidget);
    });
  });
}
