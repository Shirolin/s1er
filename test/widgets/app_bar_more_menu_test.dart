import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:s1er/models/list_density.dart';
import 'package:s1er/theme/app_theme.dart';
import 'package:s1er/widgets/app_bar_more_menu.dart';
import 'package:url_launcher/url_launcher.dart';

void main() {
  const browserUrl = 'https://stage1st.com/2b/thread-1-2-1.html';

  Future<void> pumpMenu(
    WidgetTester tester, {
    required BrowserUrlLauncher launcher,
    VoidCallback? onGoToLatest,
    VoidCallback? onHideForum,
    ListDensity? threadListDensity,
    ValueChanged<ListDensity>? onThreadListDensityChanged,
    ListDensity? postListDensity,
    ValueChanged<ListDensity>? onPostListDensityChanged,
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
                onHideForum: onHideForum,
                threadListDensity: threadListDensity,
                onThreadListDensityChanged: onThreadListDensityChanged,
                postListDensity: postListDensity,
                onPostListDensityChanged: onPostListDensityChanged,
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

  testWidgets('shows copy link and open link menu items by default',
      (tester) async {
    await pumpMenu(
      tester,
      launcher: (url, {mode = LaunchMode.platformDefault}) async => true,
    );

    await openMoreMenu(tester);

    expect(find.text('复制链接'), findsOneWidget);
    expect(find.text('输入链接'), findsOneWidget);
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

  testWidgets('shows and triggers hide forum when provided', (tester) async {
    var hideCalled = false;
    await pumpMenu(
      tester,
      launcher: (url, {mode = LaunchMode.platformDefault}) async => true,
      onHideForum: () => hideCalled = true,
    );

    await openMoreMenu(tester);

    expect(find.text('屏蔽此版块'), findsOneWidget);
    await tester.tap(find.text('屏蔽此版块'));
    await tester.pumpAndSettle();

    expect(hideCalled, isTrue);
  });

  testWidgets('shows thread list density toggles when provided',
      (tester) async {
    ListDensity? selected;
    await pumpMenu(
      tester,
      launcher: (url, {mode = LaunchMode.platformDefault}) async => true,
      threadListDensity: ListDensity.standard,
      onThreadListDensityChanged: (density) => selected = density,
    );

    await openMoreMenu(tester);

    expect(find.text('标准列表'), findsOneWidget);
    expect(find.text('紧凑列表'), findsOneWidget);
    expect(find.text('标准楼层'), findsNothing);
    // Selected row keeps semantic leading icon and shows trailing check.
    expect(find.byIcon(Icons.view_agenda_outlined), findsOneWidget);
    expect(find.byIcon(Icons.view_headline), findsOneWidget);
    expect(find.byIcon(Icons.check), findsOneWidget);
    await tester.tap(find.text('紧凑列表'));
    await tester.pumpAndSettle();

    expect(selected, ListDensity.compact);
  });

  testWidgets('shows post list density toggles when provided', (tester) async {
    ListDensity? selected;
    await pumpMenu(
      tester,
      launcher: (url, {mode = LaunchMode.platformDefault}) async => true,
      postListDensity: ListDensity.standard,
      onPostListDensityChanged: (density) => selected = density,
    );

    await openMoreMenu(tester);

    expect(find.text('标准楼层'), findsOneWidget);
    expect(find.text('紧凑楼层'), findsOneWidget);
    expect(find.text('标准列表'), findsNothing);
    await tester.tap(find.text('紧凑楼层'));
    await tester.pumpAndSettle();

    expect(selected, ListDensity.compact);
  });

  testWidgets('hides density toggles by default', (tester) async {
    await pumpMenu(
      tester,
      launcher: (url, {mode = LaunchMode.platformDefault}) async => true,
    );

    await openMoreMenu(tester);

    expect(find.text('标准列表'), findsNothing);
    expect(find.text('紧凑列表'), findsNothing);
    expect(find.text('标准楼层'), findsNothing);
    expect(find.text('紧凑楼层'), findsNothing);
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
