import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:s1_app/services/api_service.dart';

void main() {
  group('parseForumSearchHtml', () {
    test('parses hits, count and pagination', () {
      final html = File('test/fixtures/search_forum.html').readAsStringSync();
      final page = ApiService.parseForumSearchHtml(html);

      expect(page.error, isNull);
      expect(page.count, 128);
      expect(page.currentPage, 1);
      expect(page.totalPages, 7);
      expect(page.pageHref, contains('page='));
      expect(page.pageHref, isNot(contains('page=2')));
      expect(page.hits, hasLength(2));

      final first = page.hits.first;
      expect(first.tid, '2265001');
      expect(first.title, contains('Switch 2'));
      expect(first.snippet, contains('switch'));
      expect(first.forumName, '游戏论坛');
      expect(first.author, 'alice');
      expect(first.dateline, contains('2026'));

      expect(page.hits[1].tid, '2201002');
      expect(page.hits[1].author, 'bob');
    });

    test('parses empty result count', () {
      final html =
          File('test/fixtures/search_forum_empty.html').readAsStringSync();
      final page = ApiService.parseForumSearchHtml(html);
      expect(page.hits, isEmpty);
      expect(page.count, 0);
      expect(page.error, isNull);
    });

    test('surfaces rate-limit messagetext as error', () {
      final html =
          File('test/fixtures/search_rate_limited.html').readAsStringSync();
      final page = ApiService.parseForumSearchHtml(html);
      expect(page.hasError, isTrue);
      expect(page.error, contains('30 秒'));
      expect(page.hits, isEmpty);
    });

    test('throws LoginRequiredException for login form HTML', () {
      const html = '<form id="loginform_" name="login"></form>';
      expect(
        () => ApiService.parseForumSearchHtml(html),
        throwsA(isA<LoginRequiredException>()),
      );
    });
  });

  group('parseUserSearchHtml', () {
    test('parses uid and name from bbda list', () {
      final html = File('test/fixtures/search_user.html').readAsStringSync();
      final page = ApiService.parseUserSearchHtml(html);

      expect(page.error, isNull);
      expect(page.hits, hasLength(2));
      expect(page.hits[0].uid, '10001');
      expect(page.hits[0].name, 'demo_user');
      expect(page.hits[1].uid, '42');
      expect(page.hits[1].name, 'demo_user_fan');
    });

    test('surfaces messagetext error', () {
      final html =
          File('test/fixtures/search_rate_limited.html').readAsStringSync();
      final page = ApiService.parseUserSearchHtml(html);
      expect(page.hasError, isTrue);
      expect(page.error, contains('搜索'));
    });
  });
}
