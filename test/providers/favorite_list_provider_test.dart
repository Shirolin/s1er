import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:s1_app/models/user.dart';
import 'package:s1_app/providers/auth_provider.dart';
import 'package:s1_app/providers/favorite_list_provider.dart';
import 'package:s1_app/services/api_service.dart';
import 'package:s1_app/services/http_client.dart';

void main() {
  group('FavoriteListNotifier', () {
    late _FavoriteListAdapter adapter;
    late ProviderContainer container;

    setUp(() {
      adapter = _FavoriteListAdapter();
      final dio = Dio()..httpClientAdapter = adapter;
      late ProviderContainer c;
      c = ProviderContainer(
        overrides: [
          httpClientProvider.overrideWith(
            (ref) => S1HttpClient.test(c, dio),
          ),
        ],
      );
      container = c;
      container.read(authStateProvider.notifier).debugSetState(
            AuthState(
              isLoggedIn: true,
              username: 'alice',
              user: User(uid: '1', username: 'alice'),
            ),
          );
    });

    tearDown(() {
      container.dispose();
    });

    test('build loads favorite items for logged-in user', () async {
      final sub = container.listen(
        favoriteListProvider(FavoriteSegment.thread),
        (_, __) {},
      );
      addTearDown(sub.close);

      final state = await container
          .read(favoriteListProvider(FavoriteSegment.thread).future);

      expect(adapter.favoriteListRequests, greaterThan(0));
      expect(state.items, hasLength(1));
      expect(state.items.single.title, 'Favorite Thread');
      expect(state.currentPage, 1);
      expect(state.totalPages, 1);
    });

    test('build requires login before loading favorites', () async {
      final adapter = _FavoriteListAdapter();
      final dio = Dio()..httpClientAdapter = adapter;
      late ProviderContainer loggedOutContainer;
      loggedOutContainer = ProviderContainer(
        overrides: [
          authStateProvider.overrideWith(_LoggedOutAuthNotifier.new),
          httpClientProvider.overrideWith(
            (ref) => S1HttpClient.test(loggedOutContainer, dio),
          ),
        ],
      );
      addTearDown(loggedOutContainer.dispose);

      final sub = loggedOutContainer.listen(
        favoriteListProvider(FavoriteSegment.thread),
        (_, __) {},
      );
      addTearDown(sub.close);

      await Future<void>.delayed(Duration.zero);
      final asyncState = loggedOutContainer.read(
        favoriteListProvider(FavoriteSegment.thread),
      );

      expect(asyncState.hasError, isTrue);
      expect(asyncState.error, isA<LoginRequiredException>());
      expect(adapter.favoriteListRequests, 0);
    });
  });
}

class _FavoriteListAdapter implements HttpClientAdapter {
  int favoriteListRequests = 0;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final uri = options.uri;
    if (uri.queryParameters['do'] == 'favorite') {
      favoriteListRequests++;
      return ResponseBody.fromString('<html><body></body></html>', 200);
    }
    if (uri.queryParameters['module'] == 'myfavthread') {
      favoriteListRequests++;
      return ResponseBody.fromString(
        jsonEncode({
          'Variables': {
            'list': [
              {
                'favid': '10',
                'tid': '123',
                'idtype': 'tid',
                'title': 'Favorite Thread',
                'dateline': '1700000000',
              },
            ],
            'count': '1',
            'perpage': '20',
          },
        }),
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
    }
    return ResponseBody.fromString('{}', 200);
  }
}

class _LoggedOutAuthNotifier extends AuthNotifier {
  @override
  AuthState build() => AuthState();
}
