import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:s1er/theme/app_theme.dart';
import 'package:s1er/widgets/avatar_fallback.dart';

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

  testWidgets('dark theme fallback letter uses container contrast pair',
      (tester) async {
    final theme = AppTheme.darkTheme('orange');
    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: const Scaffold(
          body: AvatarFallbackLetter(radius: 18, letter: 'W'),
        ),
      ),
    );

    final avatar = tester.widget<CircleAvatar>(find.byType(CircleAvatar));
    final text = tester.widget<Text>(find.text('W'));
    expect(avatar.backgroundColor, theme.colorScheme.primaryContainer);
    expect(avatar.foregroundColor, theme.colorScheme.onPrimaryContainer);
    expect(text.style?.color, theme.colorScheme.onPrimaryContainer);
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
