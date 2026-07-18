import 'package:flutter_test/flutter_test.dart';
import 'package:s1er/models/forum_category.dart';
import 'package:s1er/utils/fid_forum_name.dart';

void main() {
  group('buildFidToForumNameMap', () {
    test('returns empty map for null categories', () {
      expect(buildFidToForumNameMap(null), isEmpty);
    });

    test('returns empty map for empty list', () {
      expect(buildFidToForumNameMap(const []), isEmpty);
    });

    test('maps top-level forum fid to name', () {
      final map = buildFidToForumNameMap([
        ForumCategory(
          fid: '2',
          name: '综合讨论区',
          description: '',
          threads: 0,
          posts: 0,
        ),
      ]);

      expect(map, {'2': '综合讨论区'});
    });

    test('maps subforum fid to name', () {
      final map = buildFidToForumNameMap([
        ForumCategory(
          fid: '2',
          name: '综合讨论区',
          description: '',
          threads: 0,
          posts: 0,
          subforums: [
            ForumCategory(
              fid: '37',
              name: '新番讨论',
              description: '',
              threads: 0,
              posts: 0,
            ),
          ],
        ),
      ]);

      expect(map['2'], '综合讨论区');
      expect(map['37'], '新番讨论');
    });
  });
}
