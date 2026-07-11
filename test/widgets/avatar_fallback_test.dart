import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:s1_app/theme/app_theme.dart';
import 'package:s1_app/widgets/avatar_fallback.dart';

void main() {
  testWidgets('AvatarFallbackLetter uses textTheme without bare fontSize', (tester) async {
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
}
