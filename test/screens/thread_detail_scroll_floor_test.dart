import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:s1_app/theme/app_theme.dart';
import 'package:s1_app/widgets/s1_fab_layout.dart';
import 'package:s1_app/widgets/s1_swipe_pagination.dart';

/// 复现帖子详情「下一楼」FAB：单击下一楼、双击页底。
class _NextFloorHarness extends StatefulWidget {
  const _NextFloorHarness();

  @override
  State<_NextFloorHarness> createState() => _NextFloorHarnessState();
}

class _NextFloorHarnessState extends State<_NextFloorHarness> {
  final _swipeKey = GlobalKey<S1SwipePaginationState>();
  late final List<GlobalKey> _postKeys =
      List.generate(4, (_) => GlobalKey());
  bool _showScrollDown = true;

  void _scrollToBottom() {
    _swipeKey.currentState?.scrollToBottom();
  }

  void _scrollToNextFloor() {
    BuildContext? anchorContext;
    for (final key in _postKeys) {
      if (key.currentContext != null) {
        anchorContext = key.currentContext;
        break;
      }
    }
    if (anchorContext == null) {
      _scrollToBottom();
      return;
    }

    final scrollable = Scrollable.maybeOf(anchorContext);
    if (scrollable == null) {
      _scrollToBottom();
      return;
    }
    final scrollOffset = scrollable.position.pixels;
    const currentFloorSlop = 48.0;

    var currentIndex = -1;
    for (var i = 0; i < _postKeys.length; i++) {
      final ctx = _postKeys[i].currentContext;
      if (ctx == null) continue;
      final renderObject = ctx.findRenderObject();
      if (renderObject == null) continue;
      final viewport = RenderAbstractViewport.maybeOf(renderObject);
      if (viewport == null) continue;
      final itemTop = viewport.getOffsetToReveal(renderObject, 0).offset;
      if (itemTop <= scrollOffset + currentFloorSlop) {
        currentIndex = i;
      }
    }

    final nextIndex = currentIndex + 1;
    if (nextIndex >= _postKeys.length) {
      _scrollToBottom();
      return;
    }

    final nextContext = _postKeys[nextIndex].currentContext;
    if (nextContext == null) {
      _scrollToBottom();
      return;
    }

    Scrollable.ensureVisible(
      nextContext,
      alignment: 0.08,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final fabPadding = S1FabLayout.contentBottomPadding(
      showScrollNavDown: _showScrollDown,
    );

    return Scaffold(
      appBar: AppBar(elevation: 0, title: const Text('Thread')),
      body: Column(
        children: [
          Expanded(
            child: S1ContentFabOverlay(
              fab: S1FabStack(
                scrollNav: S1ScrollNavConfig(
                  showScrollToTop: false,
                  showScrollDown: _showScrollDown,
                  onScrollToNextFloor: _scrollToNextFloor,
                  onScrollToBottom: _scrollToBottom,
                ),
              ),
              child: S1SwipePagination(
                key: _swipeKey,
                currentPage: 1,
                totalPages: 1,
                onPageChanged: (_) async {},
                onScrollMetricsChanged: (metrics) {
                  final show = S1FabLayout.shouldShowScrollDown(
                    metrics: metrics,
                    currentlyShowing: _showScrollDown,
                  );
                  if (show != _showScrollDown) {
                    setState(() => _showScrollDown = show);
                  }
                },
                pageBuilder: (context, scrollController) => Scrollbar(
                  controller: scrollController,
                  child: SingleChildScrollView(
                    controller: scrollController,
                    padding: EdgeInsets.only(bottom: fabPadding),
                    child: Column(
                      children: [
                        for (var i = 0; i < _postKeys.length; i++)
                          _TallPostCard(
                            key: _postKeys[i],
                            label: 'Post ${i + 1}',
                          ),
                      ],
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
  const _TallPostCard({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: SizedBox(
        height: 280,
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
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();

    final post2Top = await topOffset(tester, find.text('Post 2'));
    expect(post2Top, lessThan(appBarBottom + 120));
    expect(post2Top, greaterThan(appBarBottom - 40));

    final post1TopAfter = await topOffset(tester, find.text('Post 1'));
    expect(post1TopAfter, lessThan(post2Top));
  });

  testWidgets('double tap next-floor FAB scrolls to page bottom', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme('purple'),
        home: const _NextFloorHarness(),
      ),
    );
    await tester.pumpAndSettle();

    final down = find.byKey(const ValueKey('scroll_nav_down'));
    await tester.tap(down);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(down);
    await tester.pumpAndSettle();

    final controller = tester
        .widget<SingleChildScrollView>(find.byType(SingleChildScrollView))
        .controller!;
    expect(controller.offset, controller.position.maxScrollExtent);
  });
}
