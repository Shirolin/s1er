import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:s1_app/models/post.dart';
import 'package:s1_app/providers/settings_provider.dart';
import 'package:s1_app/theme/app_theme.dart';
import 'package:s1_app/widgets/post_item.dart';

Post _samplePost() {
  return Post(
    pid: '42',
    message: 'Hello world',
    author: 'alice',
    authorId: '1',
    dateline: 1704067200,
    floor: 3,
  );
}

void main() {
  testWidgets('PostItem renders author, message and floor badge', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsProvider.overrideWith(
            () => SettingsNotifier(initial: const AppSettings()),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme('purple'),
          home: Scaffold(
            body: PostItem(post: _samplePost()),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('alice'), findsOneWidget);
    expect(find.text('Hello world'), findsOneWidget);
    expect(find.text('#3'), findsOneWidget);
  });

  testWidgets('PostItem uses highlighted container when isHighlighted',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsProvider.overrideWith(
            () => SettingsNotifier(initial: const AppSettings()),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme('purple'),
          home: Scaffold(
            body: PostItem(
              post: _samplePost(),
              isHighlighted: true,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final card = tester.widget<Card>(find.byType(Card));
    final scheme = AppTheme.lightTheme('purple').colorScheme;
    expect(card.color, scheme.primaryContainer.withValues(alpha: S1Alpha.half));
  });
}
