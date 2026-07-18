import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:s1er/widgets/s1_click_region.dart';
import '../helpers/test_theme.dart';

void main() {
  testWidgets('S1ClickRegion uses click cursor when onTap is set',
      (tester) async {
    await tester.pumpWidget(
      wrapWithAppTheme(
        const S1ClickRegion(
          onTap: _noop,
          child: Text('tap'),
        ),
      ),
    );

    final region = tester.widget<MouseRegion>(
      find.descendant(
        of: find.byType(S1ClickRegion),
        matching: find.byType(MouseRegion),
      ),
    );
    expect(region.cursor, SystemMouseCursors.click);
  });

  testWidgets('S1ClickRegion defers cursor when not tappable', (tester) async {
    await tester.pumpWidget(
      wrapWithAppTheme(
        const S1ClickRegion(
          child: Text('static'),
        ),
      ),
    );

    final region = tester.widget<MouseRegion>(
      find.descendant(
        of: find.byType(S1ClickRegion),
        matching: find.byType(MouseRegion),
      ),
    );
    expect(region.cursor, MouseCursor.defer);
  });
}

void _noop() {}
