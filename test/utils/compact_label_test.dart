import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:s1_app/utils/compact_label.dart';

void main() {
  testWidgets('CompactLabel.text uses tight line height', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: CompactLabel.text(
              '8页',
              style: CompactLabel.style(context),
            ),
          ),
        ),
      ),
    );

    final text = tester.widget<Text>(find.text('8页'));
    expect(text.style?.height, 1.0);
    expect(text.textHeightBehavior, CompactLabel.textHeightBehavior);
  });
}
