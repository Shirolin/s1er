import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:s1_app/utils/compact_label.dart';

void main() {
  testWidgets('CompactLabel.text keeps theme line height (not forced to 1.0)', (tester) async {
    late TextStyle themeLabelSmall;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            themeLabelSmall = Theme.of(context).textTheme.labelSmall!;
            return Scaffold(
              body: CompactLabel.text(
                '8页',
                style: CompactLabel.style(context),
              ),
            );
          },
        ),
      ),
    );

    final text = tester.widget<Text>(find.text('8页'));
    expect(text.style?.height, themeLabelSmall.height);
    expect(text.textHeightBehavior, CompactLabel.textHeightBehavior);
  });

  test('visualNudge is zero (no default offset)', () {
    expect(CompactLabel.visualNudge, Offset.zero);
  });
}
