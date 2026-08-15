import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:s1er/theme/app_theme.dart';
import 'package:s1er/utils/compact_label.dart';

void main() {
  testWidgets('CompactLabel.text keeps theme line height (not forced to 1.0)',
      (tester) async {
    late TextStyle themeLabelSmall;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme('purple'),
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
    expect(text.textHeightBehavior?.applyHeightToFirstAscent, isFalse);
    expect(text.textHeightBehavior?.applyHeightToLastDescent, isFalse);
  });

  test('visualNudge is zero (no default global offset)', () {
    expect(CompactLabel.visualNudge, Offset.zero);
  });

  test('containsIdeographic detects CJK but not latin', () {
    expect(CompactLabel.containsIdeographic('新闻'), isTrue);
    expect(CompactLabel.containsIdeographic('其他'), isTrue);
    expect(CompactLabel.containsIdeographic('PC'), isFalse);
    expect(CompactLabel.containsIdeographic('8页'), isTrue);
  });

  testWidgets('CompactLabel.text nudges ideographic labels up', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme('sand'),
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: CompactLabel.text(
                '新闻',
                style: CompactLabel.style(context),
              ),
            );
          },
        ),
      ),
    );

    final translate = tester.widget<Transform>(
      find.ancestor(
        of: find.text('新闻'),
        matching: find.byType(Transform),
      ),
    );
    final dy = translate.transform.getTranslation().y;
    expect(dy, lessThan(0));
  });

  testWidgets('CompactLabel.text does not nudge latin labels', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme('sand'),
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: CompactLabel.text(
                'PC',
                style: CompactLabel.style(context),
              ),
            );
          },
        ),
      ),
    );

    expect(
      find.ancestor(of: find.text('PC'), matching: find.byType(Transform)),
      findsNothing,
    );
    expect(find.text('PC'), findsOneWidget);
  });
}
