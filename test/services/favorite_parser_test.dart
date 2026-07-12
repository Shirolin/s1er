import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:s1_app/models/favorite_item.dart';
import 'package:s1_app/services/api_service.dart';

void main() {
  group('parseFavoriteListHtml', () {
    test('parses mixed favorites from all tab HTML', () {
      final html = File('test/fixtures/favorite_all.html').readAsStringSync();
      final result = ApiService.parseFavoriteListHtml(html);

      expect(result.items.length, 2);
      expect(result.totalPages, 2);

      final thread = result.items.first;
      expect(thread.type, FavoriteType.thread);
      expect(thread.id, '2264749');
      expect(thread.favid, '3093261');
      expect(thread.title, contains('游戏机架构'));

      final forum = result.items[1];
      expect(forum.type, FavoriteType.forum);
      expect(forum.id, '4');
      expect(forum.favid, '2966493');
      expect(forum.title, '游戏论坛');
    });

    test('parses thread favorites with pagination', () {
      final html =
          File('test/fixtures/favorite_thread.html').readAsStringSync();
      final result = ApiService.parseFavoriteListHtml(html);

      expect(result.items.length, 2);
      expect(result.totalPages, 2);
      expect(result.items.every((e) => e.type == FavoriteType.thread), isTrue);
      expect(result.items.first.id, '2264749');
      expect(result.items.first.favid, '3093261');
      expect(result.items[1].id, '2202686');
      expect(result.items[1].favid, '3037118');
    });

    test('parses forum favorites', () {
      final html = File('test/fixtures/favorite_forum.html').readAsStringSync();
      final result = ApiService.parseFavoriteListHtml(html);

      expect(result.items.length, 1);
      expect(result.items.every((e) => e.type == FavoriteType.forum), isTrue);
      expect(result.items.first.id, '4');
      expect(result.items.first.favid, '2966493');
      expect(result.items.first.title, '游戏论坛');
    });

    test('returns empty list for empty-state HTML', () {
      const html =
          '<div class="findbox mt10 cl"><h4>您还没有添加任何收藏</h4></div>';
      final result = ApiService.parseFavoriteListHtml(html);
      expect(result.items, isEmpty);
    });

    test('still parses legacy threadlist_box markup', () {
      const html = '''
<div class="threadlist_box mt10 cl">
<div class="threadlist cl">
<ul>
<li class="list">
<a href="forum.php?mod=viewthread&amp;tid=2253488&amp;mobile=2">
<em>Switch 2《Splatoon RAIDERS》7月23日发售</em>
</a>
<a href="home.php?mod=spacecp&amp;ac=favorite&amp;op=delete&amp;favid=1001&amp;mobile=2" class="dialog">删除</a>
</li>
</ul>
</div>
</div>
''';
      final result = ApiService.parseFavoriteListHtml(html);
      expect(result.items.length, 1);
      expect(result.items.first.id, '2253488');
      expect(result.items.first.favid, '1001');
    });
  });

  group('parseFavoriteMutationResponse', () {
    test('detects delete success', () {
      const body = "succeedhandle_favorite('删除成功', '')";
      final result = ApiService.parseFavoriteMutationResponse(body);
      expect(result.isSuccess, isTrue);
    });

    test('detects login required', () {
      const body = 'mobile:login_before_enter_home';
      final result = ApiService.parseFavoriteMutationResponse(body);
      expect(result.error, '请先登录');
    });

    test('detects error message', () {
      const body = "errorhandle_favorite('已经收藏过了')";
      final result = ApiService.parseFavoriteMutationResponse(body);
      expect(result.error, '已经收藏过了');
    });

    test('extracts favid from succeed callback', () {
      const body =
          "succeedhandle_favorite('收藏成功', '', {'favid':'3093261'})";
      final result = ApiService.parseFavoriteMutationResponse(body);
      expect(result.isSuccess, isTrue);
      expect(result.favid, '3093261');
    });

    test('maps mobile favorite_cannot_favorite', () {
      const body = 'mobile:favorite_cannot_favorite';
      final result = ApiService.parseFavoriteMutationResponse(body);
      expect(result.error, '无法收藏该内容');
    });
  });

  group('parseFavoriteAddJson', () {
    test('detects add success with favid', () {
      final json = {
        'Message': {
          'messageval': 'favorite_succeed',
          'messagestr': '收藏成功',
        },
        'Variables': {'favid': '12345'},
      };
      final result = ApiService.parseFavoriteAddJson(json);
      expect(result.isSuccess, isTrue);
      expect(result.favid, '12345');
    });

    test('detects login required', () {
      final json = {
        'Message': {
          'messageval': 'to_login',
          'messagestr': 'mobile:to_login',
        },
      };
      final result = ApiService.parseFavoriteAddJson(json);
      expect(result.error, '请先登录');
    });

    test('maps favorite_cannot_favorite from JSON API', () {
      final json = {
        'Message': {
          'messageval': 'favorite_cannot_favorite',
          'messagestr': 'mobile:favorite_cannot_favorite',
        },
      };
      final result = ApiService.parseFavoriteAddJson(json);
      expect(result.error, '无法收藏该内容');
    });
  });

  group('parseFavoriteThreadListJson', () {
    test('reads list from data key', () {
      final json = {
        'Variables': {
          'data': [
            {
              'favid': '9',
              'id': '123',
              'idtype': 'tid',
              'title': '测试帖',
              'dateline': '1783481855',
            },
          ],
          'perpage': '20',
          'count': '1',
        },
      };
      final result = ApiService.parseFavoriteThreadListJson(json);
      expect(result.items.length, 1);
      expect(result.items.first.id, '123');
      expect(result.items.first.favid, '9');
    });
  });
}
