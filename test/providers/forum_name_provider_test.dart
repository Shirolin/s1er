import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:s1er/models/forum_category.dart';
import 'package:s1er/providers/forum_list_provider.dart';
import 'package:s1er/providers/forum_name_provider.dart';

void main() {
  group('forumNameProvider', () {
    test('resolves forum and subforum names from forumListProvider', () async {
      final categories = [
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
      ];

      final container = ProviderContainer(
        overrides: [
          forumListProvider.overrideWith(
            () => _StaticForumListNotifier(categories),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container.read(forumListProvider.future);

      expect(container.read(forumNameProvider('2')), '综合讨论区');
      expect(container.read(forumNameProvider('37')), '新番讨论');
      expect(container.read(forumNameProvider('999')), isNull);
    });
  });
}

class _StaticForumListNotifier extends ForumListNotifier {
  _StaticForumListNotifier(this._categories);

  final List<ForumCategory> _categories;

  @override
  Future<List<ForumCategory>> build() async => _categories;
}
