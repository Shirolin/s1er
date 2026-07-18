import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:s1er/theme/app_theme.dart';
import 'package:s1er/widgets/s1_fab_layout.dart';

void main() {
  testWidgets('S1FabStack shows scroll nav group and primary FAB',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme('purple'),
        home: const Scaffold(
          body: S1FabStack(
            scrollNav: S1ScrollNavConfig(
              showScrollToTop: true,
              showScrollAdvance: true,
              onScrollToTop: _noop,
              onScrollToNextFloor: _noop,
              onScrollToBottom: _noop,
            ),
            primary: S1FabItem(
              heroTag: 'reply',
              icon: Icons.edit_outlined,
              tooltip: '回复',
              onPressed: _noop,
            ),
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.keyboard_double_arrow_up), findsOneWidget);
    expect(find.byIcon(Icons.arrow_downward), findsOneWidget);
    expect(find.byIcon(Icons.edit_outlined), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsOneWidget);
    expect(find.byType(S1ScrollNavGroup), findsOneWidget);
  });

  testWidgets('S1ScrollNavGroup shows forward icon in nextPage mode',
      (tester) async {
    var nextPageTapped = false;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme('purple'),
        home: Scaffold(
          body: S1ScrollNavGroup(
            config: S1ScrollNavConfig(
              showScrollToTop: false,
              showScrollAdvance: true,
              advanceMode: ScrollNavAdvanceMode.nextPage,
              onGoToNextPage: () => nextPageTapped = true,
            ),
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.arrow_forward), findsOneWidget);
    expect(find.byIcon(Icons.arrow_downward), findsNothing);

    await tester.tap(find.byKey(const ValueKey('scroll_nav_forward')));
    await tester.pump();
    expect(nextPageTapped, isTrue);
  });

  testWidgets(
      'S1ScrollNavGroup keeps nav button size for up-only and down-only',
      (tester) async {
    Future<Size> navButtonSize(Finder finder) async {
      final box = tester.renderObject<RenderBox>(finder);
      return box.size;
    }

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme('purple'),
        home: const Scaffold(
          body: S1ScrollNavGroup(
            config: S1ScrollNavConfig(
              showScrollToTop: true,
              showScrollAdvance: false,
              onScrollToTop: _noop,
            ),
          ),
        ),
      ),
    );
    final upOnly =
        await navButtonSize(find.byKey(const ValueKey('scroll_nav_up')));

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme('purple'),
        home: const Scaffold(
          body: S1ScrollNavGroup(
            config: S1ScrollNavConfig(
              showScrollToTop: false,
              showScrollAdvance: true,
              onScrollToNextFloor: _noop,
              onScrollToBottom: _noop,
            ),
          ),
        ),
      ),
    );
    final downOnly =
        await navButtonSize(find.byKey(const ValueKey('scroll_nav_down')));

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme('purple'),
        home: const Scaffold(
          body: S1ScrollNavGroup(
            config: S1ScrollNavConfig(
              showScrollToTop: true,
              showScrollAdvance: true,
              onScrollToTop: _noop,
              onScrollToNextFloor: _noop,
              onScrollToBottom: _noop,
            ),
          ),
        ),
      ),
    );
    final upBoth =
        await navButtonSize(find.byKey(const ValueKey('scroll_nav_up')));
    final downBoth =
        await navButtonSize(find.byKey(const ValueKey('scroll_nav_down')));

    expect(
      upOnly,
      const Size(S1FabLayout.navButtonSize, S1FabLayout.navButtonSize),
    );
    expect(
      downOnly,
      const Size(S1FabLayout.navButtonSize, S1FabLayout.navButtonSize),
    );
    expect(upBoth, upOnly);
    expect(downBoth, downOnly);
  });

  testWidgets('S1ScrollNavGroup long press triggers scroll to bottom',
      (tester) async {
    var taps = 0;
    var longPresses = 0;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme('purple'),
        home: Scaffold(
          body: S1ScrollNavGroup(
            config: S1ScrollNavConfig(
              showScrollToTop: false,
              showScrollAdvance: true,
              onScrollToNextFloor: () => taps++,
              onScrollToBottom: () => longPresses++,
            ),
          ),
        ),
      ),
    );

    final down = find.byKey(const ValueKey('scroll_nav_down'));
    await tester.tap(down);
    await tester.pump();
    expect(taps, 1);
    expect(longPresses, 0);

    await tester.longPress(down);
    await tester.pumpAndSettle();
    expect(taps, 1);
    expect(longPresses, 1);
  });

  testWidgets('long press animates down icon to page bottom indicator',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme('purple'),
        home: const Scaffold(
          body: S1ScrollNavGroup(
            config: S1ScrollNavConfig(
              showScrollToTop: false,
              showScrollAdvance: true,
              onScrollToNextFloor: _noop,
              onScrollToBottom: _noop,
            ),
          ),
        ),
      ),
    );

    await tester.longPress(find.byKey(const ValueKey('scroll_nav_down')));
    await tester.pump();

    expect(find.byIcon(Icons.keyboard_double_arrow_down), findsOneWidget);
  });

  test('S1FabLayout.scrollBottomPadding is fixed edge margin', () {
    expect(
      S1FabLayout.scrollBottomPadding,
      const EdgeInsets.only(bottom: S1FabLayout.edgeMargin),
    );
  });

  test('S1FabLayout.threadDetailScrollBottomPadding matches max FAB stack', () {
    expect(S1FabLayout.threadDetailMaxFabStackHeight, 161);
    expect(
      S1FabLayout.threadDetailScrollBottomPadding,
      const EdgeInsets.only(bottom: 161),
    );
  });

  group('S1FabLayout.shouldShowScrollToTop', () {
    const viewport = 600.0;
    const showAt = viewport * S1FabLayout.scrollToTopShowFraction + 1;
    const hideAt = viewport * S1FabLayout.scrollToTopHideFraction + 1;
    const belowHide = viewport * S1FabLayout.scrollToTopHideFraction - 1;

    S1ScrollMetrics metrics(double offset) => S1ScrollMetrics(
          offset: offset,
          viewportDimension: viewport,
          maxScrollExtent: 2000,
        );

    test('shows after 15% viewport scroll', () {
      expect(
        S1FabLayout.shouldShowScrollToTop(
          metrics: metrics(showAt),
          currentlyShowing: false,
        ),
        isTrue,
      );
      expect(
        S1FabLayout.shouldShowScrollToTop(
          metrics: metrics(showAt - 2),
          currentlyShowing: false,
        ),
        isFalse,
      );
    });

    test('hides only below 5% viewport when already showing', () {
      expect(
        S1FabLayout.shouldShowScrollToTop(
          metrics: metrics(hideAt),
          currentlyShowing: true,
        ),
        isTrue,
      );
      expect(
        S1FabLayout.shouldShowScrollToTop(
          metrics: metrics(belowHide),
          currentlyShowing: true,
        ),
        isFalse,
      );
    });

    test('returns false when viewport is unknown', () {
      expect(
        S1FabLayout.shouldShowScrollToTop(
          metrics: const S1ScrollMetrics(offset: 999, viewportDimension: 0),
          currentlyShowing: false,
        ),
        isFalse,
      );
    });
  });

  group('S1FabLayout.shouldShowScrollDown', () {
    const viewport = 600.0;
    const maxExtent = 2000.0;

    S1ScrollMetrics metrics(double offset) => S1ScrollMetrics(
          offset: offset,
          viewportDimension: viewport,
          maxScrollExtent: maxExtent,
        );

    test('hides when content does not scroll', () {
      expect(
        S1FabLayout.shouldShowScrollDown(
          metrics: const S1ScrollMetrics(
            offset: 0,
            viewportDimension: viewport,
            maxScrollExtent: 0,
          ),
          currentlyShowing: false,
        ),
        isFalse,
      );
    });

    test('shows when remaining distance exceeds 12% viewport', () {
      const remainingShow = viewport * S1FabLayout.scrollDownShowFraction + 1;
      expect(
        S1FabLayout.shouldShowScrollDown(
          metrics: metrics(maxExtent - remainingShow),
          currentlyShowing: false,
        ),
        isTrue,
      );
      expect(
        S1FabLayout.shouldShowScrollDown(
          metrics: metrics(maxExtent - remainingShow + 2),
          currentlyShowing: false,
        ),
        isFalse,
      );
    });

    test('hides only at scroll end when already showing', () {
      expect(
        S1FabLayout.shouldShowScrollDown(
          metrics: metrics(maxExtent - 2),
          currentlyShowing: true,
        ),
        isTrue,
      );
      expect(
        S1FabLayout.shouldShowScrollDown(
          metrics: metrics(maxExtent),
          currentlyShowing: true,
        ),
        isFalse,
      );
    });
  });

  group('S1FabLayout.isAtPageBottom', () {
    const viewport = 600.0;
    const maxExtent = 2000.0;

    S1ScrollMetrics metrics(double offset) => S1ScrollMetrics(
          offset: offset,
          viewportDimension: viewport,
          maxScrollExtent: maxExtent,
        );

    test('true when content fits in viewport', () {
      expect(
        S1FabLayout.isAtPageBottom(
          metrics: const S1ScrollMetrics(
            offset: 0,
            viewportDimension: viewport,
            maxScrollExtent: 0,
          ),
          currentlyAtBottom: false,
        ),
        isTrue,
      );
    });

    test('detects page bottom at scroll end with hysteresis', () {
      expect(
        S1FabLayout.isAtPageBottom(
          metrics: metrics(maxExtent),
          currentlyAtBottom: false,
        ),
        isTrue,
      );

      const awayFromBottom =
          maxExtent - viewport * S1FabLayout.scrollDownShowFraction - 2;
      expect(
        S1FabLayout.isAtPageBottom(
          metrics: metrics(awayFromBottom),
          currentlyAtBottom: true,
        ),
        isFalse,
      );
    });
  });
}

void _noop() {}
