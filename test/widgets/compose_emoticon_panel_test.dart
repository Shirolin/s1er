import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:s1er/widgets/compose_emoticon_panel.dart';

import '../helpers/test_theme.dart';

void main() {
  testWidgets('ComposeEmoticonPanel uses preferredHeight when provided',
      (tester) async {
    await tester.pumpWidget(
      wrapWithAppTheme(
        ComposeEmoticonPanel(
          preferredHeight: 280,
          onSelect: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    final sized = tester.widgetList<SizedBox>(find.byType(SizedBox)).where(
          (box) => box.height == 280,
        );
    expect(sized, isNotEmpty);
  });

  testWidgets('ComposeEmoticonPanel clamps preferredHeight to 240–360',
      (tester) async {
    await tester.pumpWidget(
      wrapWithAppTheme(
        ComposeEmoticonPanel(
          preferredHeight: 500,
          onSelect: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    final sized = tester.widgetList<SizedBox>(find.byType(SizedBox)).where(
          (box) => box.height == 360,
        );
    expect(sized, isNotEmpty);
  });
}
