import 'package:flutter_test/flutter_test.dart';
import 'package:s1er/models/post.dart';
import 'package:s1er/utils/banned_post_detector.dart';
import 'package:s1er/utils/quote_recovery_helper.dart';

void main() {
  group('BannedPostDetector Tests', () {
    test('正确识别 Discuz 封禁文本', () {
      expect(
        BannedPostDetector.isBanned('提示: 作者被禁止或删除 内容自动屏蔽'),
        isTrue,
      );
      expect(
        BannedPostDetector.isBanned(
          '<div class="locked">提示: 作者被禁止或删除 内容自动屏蔽</div>',
        ),
        isTrue,
      );
      expect(
        BannedPostDetector.isBanned('该帖被管理员或版主屏蔽'),
        isTrue,
      );
    });

    test('正常帖子不触发封禁识别', () {
      expect(
        BannedPostDetector.isBanned('这是正常的楼层发言。'),
        isFalse,
      );
      expect(
        BannedPostDetector.isBanned(''),
        isFalse,
      );
    });
  });

  group('QuoteRecoveryHelper Tests', () {
    final bannedPost = Post(
      pid: '1001',
      message: '提示: 作者被禁止或删除 内容自动屏蔽',
      author: '被封用户',
      authorId: '99',
      dateline: 1700000000,
      floor: 2,
    );

    test('从 BBCode 引用中成功还原文本并识别多引用', () {
      final replyingPost1 = Post(
        pid: '1002',
        message:
            '[quote][size=2][url=forum.php?mod=redirect&goto=findpost&pid=1001&ptid=1]被封用户[/url] 发表于 2026-07-22 10:00[/size]\n被封禁账号当时说了这段很重要的话。[/quote]\n同感。',
        author: '路人甲',
        authorId: '101',
        dateline: 1700000100,
        floor: 3,
      );

      final replyingPost2 = Post(
        pid: '1003',
        message:
            '[quote][size=2][url=forum.php?mod=redirect&goto=findpost&pid=1001&ptid=1]被封用户[/url] 发表于 2026-07-22 10:05[/size]\n被封禁账号当时说了这段很重要的话。[/quote]\n确实。',
        author: '路人乙',
        authorId: '102',
        dateline: 1700000200,
        floor: 4,
      );

      final allPosts = [bannedPost, replyingPost1, replyingPost2];

      final result = QuoteRecoveryHelper.findQuotesForPost(
        targetPost: bannedPost,
        allPosts: allPosts,
      );

      expect(result.hasQuotes, isTrue);
      expect(result.totalCount, equals(2));
      expect(result.firstQuote?.sourceFloor, equals(3));
      expect(result.firstQuote?.sourceAuthor, equals('路人甲'));
      expect(result.firstQuote?.recoveredText, equals('被封禁账号当时说了这段很重要的话。'));
    });

    test('无引用时返回空结果', () {
      final normalPost = Post(
        pid: '1004',
        message: '无关回复',
        author: '路人丙',
        authorId: '103',
        dateline: 1700000300,
        floor: 5,
      );

      final result = QuoteRecoveryHelper.findQuotesForPost(
        targetPost: bannedPost,
        allPosts: [bannedPost, normalPost],
      );

      expect(result.hasQuotes, isFalse);
      expect(result.totalCount, equals(0));
      expect(result.firstQuote, isNull);
    });
  });
}
