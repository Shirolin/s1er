import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:s1_app/models/user.dart';
import 'package:s1_app/providers/auth_provider.dart';
import 'package:s1_app/providers/favorite_membership_provider.dart';
import 'package:s1_app/services/http_client.dart';

void main() {
  group('FavoriteMembershipNotifier', () {
    test('does not sync on login until ensureSynced', () async {
      final adapter = _FavoriteMembershipAdapter();
      final dio = Dio()..httpClientAdapter = adapter;
      late ProviderContainer container;
      container = ProviderContainer(
        overrides: [
          httpClientProvider.overrideWith(
            (ref) => S1HttpClient.test(container, dio),
          ),
        ],
      );
      addTearDown(container.dispose);

      container.read(favoriteMembershipProvider.notifier);
      container.read(authStateProvider.notifier).debugSetState(
            AuthState(
              isLoggedIn: true,
              username: 'alice',
              user: User(uid: '1', username: 'alice'),
            ),
          );
      await Future<void>.delayed(Duration.zero);

      expect(adapter.favoriteListRequests, 0);

      await container.read(favoriteMembershipProvider.notifier).ensureSynced();
      await Future<void>.delayed(Duration.zero);

      expect(adapter.favoriteListRequests, greaterThan(0));
      expect(container.read(favoriteMembershipProvider).keys, isEmpty);
    });
  });
}

class _FavoriteMembershipAdapter implements HttpClientAdapter {
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
    if (uri.queryParameters['do'] == 'favorite' ||
        uri.queryParameters['module'] == 'myfavthread' ||
        uri.queryParameters['module'] == 'myfavforum') {
      favoriteListRequests++;
    }
    if (uri.queryParameters['do'] == 'favorite') {
      return ResponseBody.fromString('<html><body></body></html>', 200);
    }
    if (uri.queryParameters['module'] == 'myfavthread' ||
        uri.queryParameters['module'] == 'myfavforum') {
      return ResponseBody.fromString(
        jsonEncode({
          'Variables': {
            'list': [],
            'count': '0',
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
