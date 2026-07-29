import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:s1er/models/forum_search_query.dart';
import 'package:s1er/models/search_result.dart';
import 'package:s1er/providers/api_service_provider.dart';
import 'package:s1er/providers/search_provider.dart';
import 'package:s1er/services/api_service.dart';
import 'package:s1er/services/http_client.dart';

const _hitPage1 = ForumSearchHit(
  tid: '100',
  title: 'page 1',
  forumName: 'test',
  author: 'alice',
  dateline: '2026-7-1',
);

const _hitPage2 = ForumSearchHit(
  tid: '200',
  title: 'page 2',
  forumName: 'test',
  author: 'bob',
  dateline: '2026-7-2',
);

void main() {
  group('SearchNotifier', () {
    late ProviderContainer container;
    late _StubSearchApi stub;

    ProviderSubscription<SearchUiState> keepAlive() =>
        container.listen(searchProvider, (_, __) {});

    setUp(() {
      stub = _StubSearchApi();
      container = ProviderContainer(
        overrides: [
          apiServiceProvider.overrideWithValue(stub),
        ],
      );
    });

    tearDown(() => container.dispose());

    SearchNotifier notifier() => container.read(searchProvider.notifier);
    SearchUiState state() => container.read(searchProvider);

    test('successful forum search starts cooldown', () async {
      final sub = keepAlive();
      addTearDown(sub.close);
      stub.forumResult = const ForumSearchPage(
        hits: [_hitPage1],
        count: 1,
      );

      await notifier().submit('switch');

      expect(state().forumHits, hasLength(1));
      expect(state().cooldownRemainingSeconds, 60);
      expect(state().error, isNull);
    });

    test('failed forum search does not start cooldown', () async {
      final sub = keepAlive();
      addTearDown(sub.close);
      stub.forumResult = const ForumSearchPage(error: '限流');

      await notifier().submit('switch');

      expect(state().forumHits, isEmpty);
      expect(state().error, '限流');
      expect(state().cooldownRemainingSeconds, 0);
    });

    test('goToPage success updates hits and page', () async {
      final sub = keepAlive();
      addTearDown(sub.close);
      stub.onSearchForum = ({
        required ForumSearchQuery query,
        int page = 1,
        String? pageHref,
      }) {
        if (page == 1) {
          return const ForumSearchPage(
            hits: [_hitPage1],
            count: 2,
            currentPage: 1,
            totalPages: 2,
            pageHref: 'search.php?mod=forum&page=',
          );
        }
        return const ForumSearchPage(
          hits: [_hitPage2],
          count: 2,
          currentPage: 2,
          totalPages: 2,
          pageHref: 'search.php?mod=forum&page=',
        );
      };

      await notifier().submit('switch');
      final outcome = await notifier().goToPage(2);

      expect(outcome, isA<SearchGoToPageSuccess>());
      expect(state().currentPage, 2);
      expect(state().forumHits.single.tid, '200');
      expect(state().cooldownRemainingSeconds, 60);
    });

    test('goToPage error page rolls back previous results', () async {
      final sub = keepAlive();
      addTearDown(sub.close);
      stub.onSearchForum = ({
        required ForumSearchQuery query,
        int page = 1,
        String? pageHref,
      }) {
        if (page == 1) {
          return const ForumSearchPage(
            hits: [_hitPage1],
            count: 2,
            currentPage: 1,
            totalPages: 2,
            pageHref: 'search.php?mod=forum&page=',
          );
        }
        return const ForumSearchPage(error: '翻页限流');
      };

      await notifier().submit('switch');
      final outcome = await notifier().goToPage(2);

      expect(outcome, isA<SearchGoToPageFailure>());
      expect((outcome as SearchGoToPageFailure).message, '翻页限流');
      expect(state().currentPage, 1);
      expect(state().forumHits.single.tid, '100');
      expect(state().isLoading, isFalse);
      expect(state().error, isNull);
    });

    test('goToPage login required rolls back and reports loginRequired',
        () async {
      final sub = keepAlive();
      addTearDown(sub.close);
      stub.onSearchForum = ({
        required ForumSearchQuery query,
        int page = 1,
        String? pageHref,
      }) {
        if (page == 1) {
          return const ForumSearchPage(
            hits: [_hitPage1],
            count: 2,
            currentPage: 1,
            totalPages: 2,
            pageHref: 'search.php?mod=forum&page=',
          );
        }
        throw LoginRequiredException();
      };

      await notifier().submit('switch');
      final outcome = await notifier().goToPage(2);

      expect(outcome, isA<SearchGoToPageFailure>());
      final failure = outcome as SearchGoToPageFailure;
      expect(failure.loginRequired, isTrue);
      expect(state().currentPage, 1);
      expect(state().forumHits.single.tid, '100');
      expect(state().error, isNull);
    });

    test('goToPage without pageHref fails fast without API call', () async {
      final seeded = ProviderContainer(
        overrides: [
          apiServiceProvider.overrideWithValue(stub),
          searchProvider.overrideWith(
            () => _SeededSearchNotifier(
              const SearchUiState(
                query: 'switch',
                hasSearched: true,
                forumHits: [_hitPage1],
                count: 2,
                currentPage: 1,
                totalPages: 2,
                pageHref: '',
              ),
            ),
          ),
        ],
      );
      addTearDown(seeded.dispose);
      final sub = seeded.listen(searchProvider, (_, __) {});
      addTearDown(sub.close);

      final outcome = await seeded.read(searchProvider.notifier).goToPage(2);

      expect(outcome, isA<SearchGoToPageFailure>());
      expect(stub.searchForumCallCount, 0);
    });

    test('clearAdvancedFilters resets results and advanced fields', () async {
      final sub = keepAlive();
      addTearDown(sub.close);
      stub.forumResult = const ForumSearchPage(
        hits: [_hitPage1],
        count: 1,
      );

      await notifier().submit('switch');
      notifier().updateForumQuery(
        state()
            .forumQuery
            .copyWith(author: 'alice', filter: ForumSearchFilter.digest),
      );

      notifier().clearAdvancedFilters();

      expect(state().hasSearched, isFalse);
      expect(state().forumHits, isEmpty);
      expect(state().forumQuery.author, isEmpty);
      expect(state().forumQuery.filter, ForumSearchFilter.all);
      expect(state().forumQuery.keyword, 'switch');
    });
  });
}

class _SeededSearchNotifier extends SearchNotifier {
  _SeededSearchNotifier(this.seed);

  final SearchUiState seed;

  @override
  SearchUiState build() => seed;
}

class _StubSearchApi extends ApiService {
  _StubSearchApi() : super(S1HttpClient.test(ProviderContainer(), Dio()));

  ForumSearchPage forumResult = const ForumSearchPage();
  int searchForumCallCount = 0;

  ForumSearchPage Function({
    required ForumSearchQuery query,
    int page,
    String? pageHref,
  })? onSearchForum;

  @override
  Future<ForumSearchPage> searchForum({
    required ForumSearchQuery query,
    int page = 1,
    String? pageHref,
  }) async {
    searchForumCallCount++;
    if (onSearchForum != null) {
      return onSearchForum!(
        query: query,
        page: page,
        pageHref: pageHref,
      );
    }
    return forumResult;
  }
}
