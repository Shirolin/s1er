import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:s1_app/theme/app_theme.dart';
import 'package:s1_app/widgets/s1_fab_layout.dart';

void main() {
  testWidgets('S1FabStack shows scroll nav group and primary FAB',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme('purple'),
        home: Scaffold(
          body: S1FabStack(
            scrollNav: const S1ScrollNavConfig(
              showScrollToTop: true,
              showScrollDown: true,
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

    expect(find.byIcon(Icons.arrow_upward), findsOneWidget);
    expect(find.byIcon(Icons.arrow_downward), findsOneWidget);
    expect(find.byIcon(Icons.edit_outlined), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsOneWidget);
    expect(find.byType(S1ScrollNavGroup), findsOneWidget);
  });

  testWidgets('S1ScrollNavGroup double tap disambiguates on down button',
      (tester) async {
    var taps = 0;
    var doubleTaps = 0;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme('purple'),
        home: Scaffold(
          body: S1ScrollNavGroup(
            config: S1ScrollNavConfig(
              showScrollToTop: false,
              showScrollDown: true,
              onScrollToNextFloor: () => taps++,
              onScrollToBottom: () => doubleTaps++,
            ),
          ),
        ),
      ),
    );

    final down = find.byKey(const ValueKey('scroll_nav_down'));
    await tester.tap(down);
    await tester.pump(const Duration(milliseconds: 350));
    expect(taps, 1);
    expect(doubleTaps, 0);

    await tester.tap(down);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(down);
    await tester.pump(const Duration(milliseconds: 350));
    expect(taps, 1);
    expect(doubleTaps, 1);
  });

  test('S1FabLayout.contentBottomPadding grows with visible controls', () {
    expect(
      S1FabLayout.contentBottomPadding(
        showScrollNavTop: true,
        showPrimary: true,
      ),
      greaterThan(S1FabLayout.contentBottomPadding(showPrimary: true)),
    );
    expect(
      S1FabLayout.contentBottomPadding(
        showScrollNavTop: true,
        showScrollNavDown: true,
        showPrimary: true,
      ),
      greaterThan(
        S1FabLayout.contentBottomPadding(
          showScrollNavTop: true,
          showPrimary: true,
        ),
      ),
    );
    expect(S1FabLayout.contentBottomPadding(), 16);
  });

  test('S1FabLayout.scrollNavGroupHeight accounts for one or two buttons', () {
    expect(
      S1FabLayout.scrollNavGroupHeight(showScrollDown: true),
      greaterThan(0),
    );
    expect(
      S1FabLayout.scrollNavGroupHeight(
        showScrollToTop: true,
        showScrollDown: true,
      ),
      greaterThan(
        S1FabLayout.scrollNavGroupHeight(showScrollDown: true),
      ),
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
      final remainingShow =
          viewport * S1FabLayout.scrollDownShowFraction + 1;
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

    test('hides only within 4% viewport of bottom when already showing', () {
      final remainingHide =
          viewport * S1FabLayout.scrollDownHideFraction + 1;
      expect(
        S1FabLayout.shouldShowScrollDown(
          metrics: metrics(maxExtent - remainingHide),
          currentlyShowing: true,
        ),
        isTrue,
      );
      expect(
        S1FabLayout.shouldShowScrollDown(
          metrics: metrics(maxExtent - remainingHide + 2),
          currentlyShowing: true,
        ),
        isFalse,
      );
    });
  });
}

void _noop() {}
