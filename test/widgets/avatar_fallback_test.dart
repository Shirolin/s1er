import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:s1_app/theme/app_theme.dart';
import 'package:s1_app/widgets/avatar_fallback.dart';

void main() {
  testWidgets('AvatarFallbackLetter uses textTheme without bare fontSize',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme('purple'),
        home: const Scaffold(
          body: AvatarFallbackLetter(radius: 44, letter: 'A'),
        ),
      ),
    );

    final text = tester.widget<Text>(find.text('A'));
    expect(text.style?.fontSize, isNotNull);
    expect(text.style?.height, 1.0);
    expect(find.byType(AvatarFallbackLetter), findsOneWidget);
  });

  testWidgets('AvatarFallbackLetter fits within small radius', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme('purple'),
        home: const Scaffold(
          body: AvatarFallbackLetter(radius: 20, letter: '张'),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
  });

  testWidgets('ideographic letter gets optical upward nudge', (tester) async {
    const radius = 20.0;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme('purple'),
        home: const Scaffold(
          body: AvatarFallbackLetter(radius: radius, letter: '小'),
        ),
      ),
    );

    final translate = tester.widget<Transform>(
      find.descendant(
        of: find.byType(AvatarFallbackLetter),
        matching: find.byType(Transform),
      ),
    );
    expect(translate.transform.getTranslation().y, -radius * 0.06);
  });

  testWidgets('latin letter has no optical nudge', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme('purple'),
        home: const Scaffold(
          body: AvatarFallbackLetter(radius: 20, letter: 'b'),
        ),
      ),
    );

    final translate = tester.widget<Transform>(
      find.descendant(
        of: find.byType(AvatarFallbackLetter),
        matching: find.byType(Transform),
      ),
    );
    expect(translate.transform.getTranslation().y, 0);
  });

  test('isIdeographic distinguishes CJK from latin', () {
    expect(AvatarFallbackLetter.isIdeographic('小'), isTrue);
    expect(AvatarFallbackLetter.isIdeographic('张'), isTrue);
    expect(AvatarFallbackLetter.isIdeographic('あ'), isTrue);
    expect(AvatarFallbackLetter.isIdeographic('한'), isTrue);
    expect(AvatarFallbackLetter.isIdeographic('b'), isFalse);
    expect(AvatarFallbackLetter.isIdeographic('A'), isFalse);
    expect(AvatarFallbackLetter.isIdeographic('?'), isFalse);
    expect(AvatarFallbackLetter.isIdeographic(''), isFalse);
  });
}
