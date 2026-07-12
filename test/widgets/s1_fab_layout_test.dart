import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:s1_app/theme/app_theme.dart';
import 'package:s1_app/widgets/s1_fab_layout.dart';

void main() {
  testWidgets('S1FabStack shows primary and secondary FABs', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme('purple'),
        home: Scaffold(
          body: S1FabStack(
            secondary: S1FabItem(
              heroTag: 'top',
              icon: Icons.arrow_upward,
              tooltip: '返回顶部',
              onPressed: () {},
              small: true,
            ),
            primary: S1FabItem(
              heroTag: 'reply',
              icon: Icons.edit_outlined,
              tooltip: '回复',
              onPressed: () {},
            ),
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.arrow_upward), findsOneWidget);
    expect(find.byIcon(Icons.edit_outlined), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsNWidgets(2));
  });

  test('S1FabLayout.contentBottomPadding grows with visible FABs', () {
    expect(
      S1FabLayout.contentBottomPadding(showSecondary: true, showPrimary: true),
      greaterThan(S1FabLayout.contentBottomPadding(showPrimary: true)),
    );
    expect(S1FabLayout.contentBottomPadding(), 16);
  });

  group('S1FabLayout.shouldShowScrollToTop', () {
    const viewport = 600.0;
    const showAt = viewport * S1FabLayout.scrollToTopShowFraction + 1;
    const hideAt = viewport * S1FabLayout.scrollToTopHideFraction + 1;
    const belowHide = viewport * S1FabLayout.scrollToTopHideFraction - 1;

    S1ScrollMetrics metrics(double offset) => S1ScrollMetrics(
          offset: offset,
          viewportDimension: viewport,
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
}
