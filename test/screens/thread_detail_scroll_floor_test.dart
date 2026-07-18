import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:s1er/theme/app_theme.dart';
import 'package:s1er/utils/scroll_floor.dart';
import 'package:s1er/widgets/s1_fab_layout.dart';
import 'package:s1er/widgets/s1_swipe_pagination.dart';

int? _harnessRequestedPage;

/// 与帖子详情一致的 FAB 显隐状态（ValueNotifier，不重建列表）。
class _ScrollFabVisibility {
  const _ScrollFabVisibility({
    this.showScrollDown = false,
    this.atPageBottom = false,
  });

  final bool showScrollDown;
  final bool atPageBottom;
}

/// 复现帖子详情「下一楼」导航：单击下一楼、长按页底。
class _NextFloorHarness extends StatefulWidget {
  const _NextFloorHarness({
    this.shortPosts = false,
    this.tallPostHeight = 280,
    this.currentPage = 1,
    this.totalPages = 1,
  });

  final bool shortPosts;
  final double tallPostHeight;
  final int currentPage;
  final int totalPages;

  @override
  State<_NextFloorHarness> createState() => _NextFloorHarnessState();
}

class _NextFloorHarnessState extends State<_NextFloorHarness> {
  final _swipeKey = GlobalKey<S1SwipePaginationState>();
  late final List<GlobalKey> _postKeys = List.generate(4, (_) => GlobalKey());
  final _scrollFabVisibility =
      ValueNotifier(const _ScrollFabVisibility(showScrollDown: true));

  @override
  void dispose() {
    _scrollFabVisibility.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    _swipeKey.currentState?.scrollToBottom();
  }

  void _onScrollMetricsChanged(S1ScrollMetrics metrics) {
    final fab = _scrollFabVisibility.value;
    final showDown = S1FabLayout.shouldShowScrollDown(
      metrics: metrics,
      currentlyShowing: fab.showScrollDown,
    );
    final atBottom = S1FabLayout.isAtPageBottom(
      metrics: metrics,
      currentlyAtBottom: fab.atPageBottom,
    );
    if (showDown != fab.showScrollDown || atBottom != fab.atPageBottom) {
      _scrollFabVisibility.value = _ScrollFabVisibility(
        showScrollDown: showDown,
        atPageBottom: atBottom,
      );
    }
  }

  void _scrollToNextFloor() {
    ScrollFloorNavigator.scrollToNextFloor(
      postKeys: _postKeys,
      onAtLastFloor: _scrollToBottom,
    );
  }

  Future<void> _goToPage(int page) async {
    _harnessRequestedPage = page;
    await _swipeKey.currentState?.scrollToTop();
  }

  @override
  Widget build(BuildContext context) {
    final hasNextPage = widget.currentPage < widget.totalPages;

    return Scaffold(
      appBar: AppBar(elevation: 0, title: const Text('Thread')),
      body: Column(
        children: [
          Expanded(
            child: S1ContentFabOverlay(
              fab: ValueListenableBuilder<_ScrollFabVisibility>(
                valueListenable: _scrollFabVisibility,
                builder: (context, fab, _) {
                  final showScrollAdvance =
                      fab.showScrollDown || (fab.atPageBottom && hasNextPage);
                  final advanceMode = fab.atPageBottom && hasNextPage
                      ? ScrollNavAdvanceMode.nextPage
                      : ScrollNavAdvanceMode.nextFloor;
                  return S1FabStack(
                    scrollNav: S1ScrollNavConfig(
                      showScrollToTop: false,
                      showScrollAdvance: showScrollAdvance,
                      advanceMode: advanceMode,
                      onScrollToNextFloor: _scrollToNextFloor,
                      onScrollToBottom: _scrollToBottom,
                      onGoToNextPage: hasNextPage
                          ? () => _goToPage(widget.currentPage + 1)
                          : null,
                    ),
                  );
                },
              ),
              child: S1SwipePagination(
                key: _swipeKey,
                currentPage: widget.currentPage,
                totalPages: widget.totalPages,
                onPageChanged: (page) async {
                  _harnessRequestedPage = page;
                },
                onScrollMetricsChanged: _onScrollMetricsChanged,
                pageBuilder: (context, scrollController) => Scrollbar(
                  controller: scrollController,
                  child: ListView.builder(
                    controller: scrollController,
                    padding: S1FabLayout.threadDetailScrollBottomPadding,
                    itemCount: _postKeys.length,
                    itemBuilder: (context, i) => widget.shortPosts
                        ? _ShortPostCard(
                            key: _postKeys[i],
                            label: 'Post ${i + 1}',
                          )
                        : _TallPostCard(
                            key: _postKeys[i],
                            label: 'Post ${i + 1}',
                            height: widget.tallPostHeight,
                          ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 48),
        ],
      ),
    );
  }
}

class _TallPostCard extends StatelessWidget {
  const _TallPostCard({
    super.key,
    required this.label,
    required this.height,
  });

  final String label;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: SizedBox(
        height: height,
        child: Align(
          alignment: Alignment.topLeft,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Text(label),
          ),
        ),
      ),
    );
  }
}

class _ShortPostCard extends StatelessWidget {
  const _ShortPostCard({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: SizedBox(
        // 足够高以产生可滚动距离（稳定 FAB 占位后仍显示 ↓）。
        height: 200,
        child: Align(
          alignment: Alignment.topLeft,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Text(label),
          ),
        ),
      ),
    );
  }
}

void main() {
  Future<double> topOffset(WidgetTester tester, Finder finder) async {
    final box = tester.renderObject<RenderBox>(finder);
    return box.localToGlobal(Offset.zero).dy;
  }

  testWidgets('single tap next-floor FAB scrolls to Post 2', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme('purple'),
        home: const _NextFloorHarness(),
      ),
    );
    await tester.pumpAndSettle();

    final appBarBottom = tester.getBottomLeft(find.byType(AppBar)).dy;
    final post1TopBefore = await topOffset(tester, find.text('Post 1'));
    expect(post1TopBefore, lessThan(appBarBottom + 40));

    final down = find.byKey(const ValueKey('scroll_nav_down'));
    await tester.tap(down);
    await tester.pumpAndSettle();

    final post2Top = await topOffset(tester, find.text('Post 2'));
    expect(post2Top, lessThan(appBarBottom + 120));
    expect(post2Top, greaterThan(appBarBottom - 40));

    final post1TopAfter = await topOffset(tester, find.text('Post 1'));
    expect(post1TopAfter, lessThan(post2Top));
  });

  testWidgets('next-floor scrolls even when next post is already visible',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme('purple'),
        home: const _NextFloorHarness(shortPosts: true),
      ),
    );
    await tester.pumpAndSettle();

    final controller =
        tester.widget<ListView>(find.byType(ListView)).controller!;
    expect(controller.offset, 0);

    final post2TopBefore = await topOffset(tester, find.text('Post 2'));
    expect(post2TopBefore, greaterThan(0));

    await tester.tap(find.byKey(const ValueKey('scroll_nav_down')));
    await tester.pumpAndSettle();

    expect(controller.offset, greaterThan(0));

    final post2TopAfter = await topOffset(tester, find.text('Post 2'));
    expect(post2TopAfter, lessThan(post2TopBefore));
  });

  testWidgets('single tap builds and scrolls to an unbuilt next floor',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme('purple'),
        home: const _NextFloorHarness(tallPostHeight: 1200),
      ),
    );
    await tester.pumpAndSettle();

    final controller =
        tester.widget<ListView>(find.byType(ListView)).controller!;
    expect(find.text('Post 2'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('scroll_nav_down')));
    await tester.pumpAndSettle();

    expect(find.text('Post 2'), findsOneWidget);
    expect(controller.offset, lessThan(controller.position.maxScrollExtent));
  });

  testWidgets('long press scrolls to page bottom', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme('purple'),
        home: const _NextFloorHarness(shortPosts: true),
      ),
    );
    await tester.pumpAndSettle();

    final controller =
        tester.widget<ListView>(find.byType(ListView)).controller!;

    await tester.longPress(find.byKey(const ValueKey('scroll_nav_down')));
    await tester.pumpAndSettle();

    expect(controller.offset, controller.position.maxScrollExtent);
  });

  testWidgets('long press from top reaches bottom with lazy tall posts',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme('purple'),
        home: const _NextFloorHarness(),
      ),
    );
    await tester.pumpAndSettle();

    final controller =
        tester.widget<ListView>(find.byType(ListView)).controller!;
    expect(controller.offset, 0);

    await tester.longPress(find.byKey(const ValueKey('scroll_nav_down')));
    await tester.pumpAndSettle();

    expect(
      controller.offset,
      closeTo(controller.position.maxScrollExtent, 0.5),
    );
  });

  testWidgets('at page bottom shows forward and requests next page',
      (tester) async {
    _harnessRequestedPage = null;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme('purple'),
        home: const _NextFloorHarness(
          shortPosts: true,
          currentPage: 1,
          totalPages: 3,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.longPress(find.byKey(const ValueKey('scroll_nav_down')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('scroll_nav_forward')), findsOneWidget);
    expect(find.byKey(const ValueKey('scroll_nav_down')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('scroll_nav_forward')));
    await tester.pumpAndSettle();

    expect(_harnessRequestedPage, 2);
  });

  testWidgets('long press on forward still scrolls to page bottom',
      (tester) async {
    _harnessRequestedPage = null;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme('purple'),
        home: const _NextFloorHarness(
          shortPosts: true,
          currentPage: 1,
          totalPages: 3,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final controller =
        tester.widget<ListView>(find.byType(ListView)).controller!;

    await tester.longPress(find.byKey(const ValueKey('scroll_nav_down')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('scroll_nav_forward')), findsOneWidget);
    expect(controller.offset, controller.position.maxScrollExtent);

    await tester.longPress(find.byKey(const ValueKey('scroll_nav_forward')));
    await tester.pumpAndSettle();

    expect(
      controller.offset,
      closeTo(controller.position.maxScrollExtent, 0.5),
    );
    expect(_harnessRequestedPage, isNull);
  });

  testWidgets('FAB at-bottom update does not shift scroll offset',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme('purple'),
        home: const _NextFloorHarness(
          shortPosts: true,
          currentPage: 1,
          totalPages: 3,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final controller =
        tester.widget<ListView>(find.byType(ListView)).controller!;
    await tester.longPress(find.byKey(const ValueKey('scroll_nav_down')));
    await tester.pumpAndSettle();

    final offsetAtBottom = controller.offset;
    expect(offsetAtBottom, controller.position.maxScrollExtent);
    expect(find.byKey(const ValueKey('scroll_nav_forward')), findsOneWidget);

    await tester.pump();
    expect(controller.offset, offsetAtBottom);
  });
}
