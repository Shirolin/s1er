import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:s1_app/widgets/s1_fab_layout.dart';

void main() {
  testWidgets('S1FabStack shows primary and secondary FABs', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
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
}
