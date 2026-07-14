import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:s1_app/models/search_result.dart';
import 'package:s1_app/providers/search_provider.dart';
import 'package:s1_app/screens/search_screen.dart';
import 'package:s1_app/theme/app_theme.dart';

class _SeededSearchNotifier extends SearchNotifier {
  @override
  SearchUiState build() => const SearchUiState(
        hasSearched: true,
        query: 'switch',
        forumHits: [
          ForumSearchHit(
            tid: '100',
            title: '假帖 switch',
            snippet: '摘要',
            forumName: '游戏论坛',
            author: 'alice',
            dateline: '2026-7-1',
          ),
        ],
        count: 1,
      );
}

void main() {
  testWidgets('SearchScreen idle shows type hint', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.lightTheme('purple'),
          home: const Scaffold(body: SearchScreen()),
        ),
      ),
    );

    expect(find.text('搜索主题与帖子'), findsOneWidget);
    expect(find.text('主题'), findsOneWidget);
    expect(find.text('用户'), findsOneWidget);
  });

  testWidgets('SearchScreen shows seeded forum hits', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          searchProvider.overrideWith(_SeededSearchNotifier.new),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme('purple'),
          home: const Scaffold(body: SearchScreen()),
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.text('假帖 switch'), findsOneWidget);
    expect(find.textContaining('找到 1 条'), findsOneWidget);
    expect(find.textContaining('游戏论坛'), findsOneWidget);
  });
}
