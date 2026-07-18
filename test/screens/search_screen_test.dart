import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:s1er/models/search_result.dart';
import 'package:s1er/providers/api_service_provider.dart';
import 'package:s1er/providers/search_provider.dart';
import 'package:s1er/screens/search_screen.dart';
import 'package:s1er/services/api_service.dart';
import 'package:s1er/services/http_client.dart';
import 'package:s1er/theme/app_theme.dart';

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

class _FakeSearchApiService extends ApiService {
  _FakeSearchApiService()
      : super(S1HttpClient.test(ProviderContainer(), Dio()));

  @override
  Future<ForumSearchPage> searchForum({
    required String query,
    int page = 1,
    String? pageHref,
  }) async {
    return const ForumSearchPage(
      hits: [
        ForumSearchHit(
          tid: '100',
          title: '倒计时测试主题',
          forumName: '游戏论坛',
          author: 'alice',
          dateline: '2026-7-1',
        ),
      ],
      count: 1,
    );
  }
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
    expect(find.byTooltip('请输入搜索关键词'), findsOneWidget);
  });

  testWidgets('SearchScreen empty query keeps submit disabled', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.lightTheme('purple'),
          home: const Scaffold(body: SearchScreen()),
        ),
      ),
    );

    await tester.enterText(find.byType(SearchBar), '   ');
    await tester.pump();
    expect(find.byTooltip('请输入搜索关键词'), findsOneWidget);

    await tester.enterText(find.byType(SearchBar), 'switch');
    await tester.pump();
    expect(find.byTooltip('搜索'), findsOneWidget);
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
    expect(find.byType(Card), findsOneWidget);
    expect(find.byType(Chip), findsOneWidget);
  });

  testWidgets('SearchScreen cooldown countdown updates every second',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          apiServiceProvider.overrideWithValue(_FakeSearchApiService()),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme('purple'),
          home: const Scaffold(body: SearchScreen()),
        ),
      ),
    );

    await tester.enterText(find.byType(SearchBar), 'switch');
    await tester.pump();
    await tester.tap(find.byTooltip('搜索'));
    await tester.pump();

    expect(find.text('搜索间隔中，30 秒后可再搜索'), findsOneWidget);
    expect(find.byTooltip('搜索间隔中'), findsOneWidget);

    await tester.pump(const Duration(seconds: 1));
    expect(find.text('搜索间隔中，29 秒后可再搜索'), findsOneWidget);

    await tester.pump(const Duration(seconds: 29));
    expect(find.textContaining('搜索间隔中'), findsNothing);
    expect(find.byTooltip('搜索'), findsOneWidget);
  });
}
