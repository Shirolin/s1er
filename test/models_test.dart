import 'package:flutter_test/flutter_test.dart';
import 'package:s1_app/models/thread.dart';
import 'package:s1_app/models/post.dart';
import 'package:s1_app/models/forum_category.dart';
import 'package:s1_app/models/user.dart';
import 'package:s1_app/models/emoticon.dart';

void main() {
  group('Thread', () {
    test('parses from JSON', () {
      final json = {
        'tid': '12345',
        'subject': 'Test Thread',
        'author': 'testuser',
        'authorid': '100',
        'dateline': '1700000000',
        'views': '500',
        'replies': '20',
        'fid': '4',
      };
      final thread = Thread.fromJson(json);
      expect(thread.tid, '12345');
      expect(thread.subject, 'Test Thread');
      expect(thread.author, 'testuser');
      expect(thread.views, 500);
      expect(thread.replies, 20);
    });

    test('serializes to JSON', () {
      final thread = Thread(
        tid: '1',
        subject: 'Hello',
        author: 'user',
        authorId: '10',
        dateline: 1700000000,
        views: 100,
        replies: 5,
        fid: '4',
      );
      final json = thread.toJson();
      expect(json['tid'], '1');
      expect(json['subject'], 'Hello');
      expect(json['views'], 100);
    });

    test('handles missing optional fields', () {
      final thread = Thread.fromJson({});
      expect(thread.tid, '');
      expect(thread.subject, '');
      expect(thread.views, 0);
    });

    test('parses optional fields', () {
      final json = {
        'tid': '1',
        'subject': 'Test',
        'author': 'user',
        'authorid': '10',
        'dateline': '0',
        'views': '0',
        'replies': '0',
        'fid': '4',
        'lastpost': '2024-01-01',
        'lastposter': 'lastuser',
      };
      final thread = Thread.fromJson(json);
      expect(thread.lastPost, '2024-01-01');
      expect(thread.lastPoster, 'lastuser');
    });
  });

  group('Post', () {
    test('parses from JSON', () {
      final json = {
        'pid': '67890',
        'message': 'Hello world',
        'author': 'user1',
        'authorid': '200',
        'dateline': '1700001000',
        'floor': 1,
      };
      final post = Post.fromJson(json);
      expect(post.pid, '67890');
      expect(post.message, 'Hello world');
      expect(post.floor, 1);
    });

    test('handles missing fields gracefully', () {
      final post = Post.fromJson({});
      expect(post.pid, '');
      expect(post.message, '');
      expect(post.floor, 0);
    });

    test('parses avatar field', () {
      final json = {
        'pid': '1',
        'message': 'Hi',
        'author': 'user',
        'authorid': '1',
        'dateline': '0',
        'floor': 1,
        'avatar': 'https://example.com/avatar.jpg',
      };
      final post = Post.fromJson(json);
      expect(post.avatar, 'https://example.com/avatar.jpg');
    });
  });

  group('ForumCategory', () {
    test('parses from JSON', () {
      final json = {
        'fid': '4',
        'name': '技术讨论',
        'description': 'Tech discussion',
        'threads': '1000',
        'posts': '5000',
      };
      final cat = ForumCategory.fromJson(json);
      expect(cat.fid, '4');
      expect(cat.name, '技术讨论');
      expect(cat.threads, 1000);
      expect(cat.posts, 5000);
    });

    test('handles missing fields', () {
      final cat = ForumCategory.fromJson({});
      expect(cat.fid, '');
      expect(cat.name, '');
      expect(cat.threads, 0);
    });

    test('parses optional icon field', () {
      final json = {
        'fid': '1',
        'name': 'General',
        'description': '',
        'threads': '0',
        'posts': '0',
        'icon': 'icon.png',
      };
      final cat = ForumCategory.fromJson(json);
      expect(cat.icon, 'icon.png');
    });
  });

  group('User', () {
    test('parses from JSON', () {
      final json = {
        'uid': '100',
        'username': 'testuser',
        'avatar': 'https://example.com/avatar.jpg',
        'groupTitle': '会员',
      };
      final user = User.fromJson(json);
      expect(user.uid, '100');
      expect(user.username, 'testuser');
      expect(user.avatar, 'https://example.com/avatar.jpg');
      expect(user.groupTitle, '会员');
    });

    test('handles missing optional fields', () {
      final user = User.fromJson({});
      expect(user.uid, '');
      expect(user.username, '');
      expect(user.avatar, null);
      expect(user.groupTitle, null);
    });
  });

  group('Emoticon', () {
    test('creates emoticon with code and path', () {
      final emoticon = Emoticon(
        code: '[f:001]',
        assetPath: 'assets/emoticons/001.png',
      );
      expect(emoticon.code, '[f:001]');
      expect(emoticon.assetPath, 'assets/emoticons/001.png');
    });

    test('EmoticonMap initializes with 100 entries', () {
      EmoticonMap.initialize();
      expect(EmoticonMap.all.length, 100);
    });

    test('EmoticonMap returns correct asset path', () {
      EmoticonMap.initialize();
      expect(
        EmoticonMap.getAssetPath('[f:001]'),
        'assets/emoticons/001.png',
      );
      expect(
        EmoticonMap.getAssetPath('[f:100]'),
        'assets/emoticons/100.png',
      );
    });

    test('EmoticonMap returns null for unknown code', () {
      EmoticonMap.initialize();
      expect(EmoticonMap.getAssetPath('[f:999]'), null);
    });
  });
}
