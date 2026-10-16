import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:s1er/theme/app_theme.dart';
import 'package:s1er/utils/scroll_floor.dart';

void main() {
  testWidgets('scrollToIndex brings a distant index into view', (tester) async {
    final keys = List.generate(40, (_) => GlobalKey());
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme('purple'),
        home: Scaffold(
          body: ListView.builder(
            itemCount: keys.length,
            itemBuilder: (context, index) {
              return SizedBox(
                key: keys[index],
                height: 120,
                child: Text('floor-$index'),
              );
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('floor-0'), findsOneWidget);
    expect(find.text('floor-25'), findsNothing);

    // Estimate and final align both jump instantly.
    final future = ScrollFloorNavigator.scrollToIndex(
      postKeys: keys,
      index: 25,
    );
    await tester.pumpAndSettle();
    final ok = await future;

    expect(ok, isTrue);
    expect(find.text('floor-25'), findsOneWidget);
  });

  testWidgets(
      'scrollToIndex does not overshoot to last floor when early posts are tall',
      (tester) async {
    final keys = List.generate(40, (_) => GlobalKey());
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme('purple'),
        home: Scaffold(
          body: ListView.builder(
            itemCount: keys.length,
            itemBuilder: (context, index) {
              // OP / early floor is very tall (e.g. long post with images),
              // while subsequent floors are normal/short.
              final height = index == 0 ? 1200.0 : 120.0;
              return SizedBox(
                key: keys[index],
                height: height,
                child: Text('floor-${index + 1}'),
              );
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Target floor 31 (index 30), matching #46: 30-floor thread grows to 40+ on page 1.
    final future = ScrollFloorNavigator.scrollToIndex(
      postKeys: keys,
      index: 30,
    );
    await tester.pumpAndSettle();
    final ok = await future;

    expect(ok, isTrue);
    expect(find.text('floor-31'), findsOneWidget);
    final leading = ScrollFloorNavigator.findLeadingVisiblePostIndex(
      postKeys: keys,
    );
    expect(leading, 30);
  });
}
