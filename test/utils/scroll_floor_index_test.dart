import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:s1_app/theme/app_theme.dart';
import 'package:s1_app/utils/scroll_floor.dart';

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

    // Must pump while animateTo runs; awaiting first would deadlock the ticker.
    final future = ScrollFloorNavigator.scrollToIndex(
      postKeys: keys,
      index: 25,
    );
    await tester.pumpAndSettle();
    final ok = await future;

    expect(ok, isTrue);
    expect(find.text('floor-25'), findsOneWidget);
  });
}
