import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:s1er/theme/app_theme.dart';
import 'package:s1er/widgets/app_bar_more_menu.dart';
import 'package:url_launcher/url_launcher.dart';

void main() {
  const browserUrl = 'https://stage1st.com/2b/thread-1-2-1.html';

  Future<void> pumpMenu(
    WidgetTester tester, {
    required BrowserUrlLauncher launcher,
    VoidCallback? onGoToLatest,
  }) {
    return tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme('purple'),
        home: Scaffold(
          appBar: AppBar(
            elevation: 0,
            actions: [
              AppBarMoreMenu(
                browserUrl: browserUrl,
                launcher: launcher,
                onGoToLatest: onGoToLatest,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> openMoreMenu(WidgetTester tester) async {
    await tester.tap(find.byTooltip('更多操作'));
    await tester.pumpAndSettle();
  }

  Future<void> openBrowserMenu(WidgetTester tester) async {
    await openMoreMenu(tester);
    await tester.tap(find.text('通过浏览器打开'));
    await tester.pumpAndSettle();
  }

  testWidgets('shows copy link menu item', (tester) async {
    await pumpMenu(
      tester,
      launcher: (url, {mode = LaunchMode.platformDefault}) async => true,
    );

    await openMoreMenu(tester);

    // Menu item is visible.
    expect(find.text('复制链接'), findsOneWidget);
  });

  testWidgets('shows and triggers go to latest menu item when provided',
      (tester) async {
    var goToLatestCalled = false;
    await pumpMenu(
      tester,
      launcher: (url, {mode = LaunchMode.platformDefault}) async => true,
      onGoToLatest: () => goToLatestCalled = true,
    );

    await openMoreMenu(tester);

    expect(find.text('跳转到最新'), findsOneWidget);
    await tester.tap(find.text('跳转到最新'));
    await tester.pumpAndSettle();

    expect(goToLatestCalled, isTrue);
  });

  testWidgets('opens the URL in an external application', (tester) async {
    Uri? receivedUrl;
    LaunchMode? receivedMode;
    await pumpMenu(
      tester,
      launcher: (url, {mode = LaunchMode.platformDefault}) async {
        receivedUrl = url;
        receivedMode = mode;
        return true;
      },
    );

    await openBrowserMenu(tester);

    expect(receivedUrl?.toString(), browserUrl);
    expect(receivedMode, LaunchMode.externalApplication);
    expect(find.text('无法打开浏览器'), findsNothing);
  });

  testWidgets('shows feedback when the browser cannot be opened',
      (tester) async {
    await pumpMenu(
      tester,
      launcher: (url, {mode = LaunchMode.platformDefault}) async => false,
    );

    await openBrowserMenu(tester);

    expect(find.text('无法打开浏览器'), findsOneWidget);
  });

  testWidgets('shows feedback when opening the browser throws', (tester) async {
    await pumpMenu(
      tester,
      launcher: (url, {mode = LaunchMode.platformDefault}) async {
        throw StateError('launcher unavailable');
      },
    );

    await openBrowserMenu(tester);

    expect(find.text('无法打开浏览器'), findsOneWidget);
  });
}
