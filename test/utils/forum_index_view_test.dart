import 'package:flutter_test/flutter_test.dart';
import 'package:s1er/models/forum_category.dart';
import 'package:s1er/utils/forum_index_view.dart';

ForumCategory _cat({
  required String fid,
  required String name,
  List<ForumCategory> subforums = const [],
  int todayPosts = 0,
}) {
  return ForumCategory(
    fid: fid,
    name: name,
    description: '',
    threads: 1,
    posts: 1,
    todayPosts: todayPosts,
    subforums: subforums,
  );
}

void main() {
  final categories = [
    _cat(
      fid: 'c1',
      name: '分类一',
      subforums: [
        _cat(fid: '1', name: '外野', todayPosts: 3),
        _cat(fid: '2', name: '动漫', todayPosts: 1),
      ],
    ),
    _cat(
      fid: 'c2',
      name: '分类二',
      subforums: [
        _cat(fid: '3', name: '游戏'),
      ],
    ),
    _cat(fid: '99', name: '独立版块'),
  ];

  test('filterHiddenForums removes leaves and empty categories', () {
    final filtered = filterHiddenForums(categories, {'2', '3', '99'});
    expect(filtered, hasLength(1));
    expect(filtered.single.fid, 'c1');
    expect(filtered.single.subforums.map((f) => f.fid), ['1']);
  });

  test('buildForumIndexView pins favorites and skips hidden', () {
    final view = buildForumIndexView(
      categories: categories,
      favoriteFidsOrdered: ['2', '1', '404', '2'],
      favoriteTitleFor: (fid) => fid == '404' ? '失踪版块' : fid,
      hiddenForums: {'2'},
    );

    expect(view.pinned.map((f) => f.fid).toList(), ['1', '404']);
    expect(view.pinned[0].name, '外野');
    expect(view.pinned[0].todayPosts, 3);
    expect(view.pinned[1].name, '失踪版块');

    expect(
      view.categories.expand((c) => c.subforums).map((f) => f.fid),
      isNot(contains('2')),
    );
    expect(view.categories.any((c) => c.fid == 'c1'), isTrue);
  });

  test('buildForumIndexView keeps pin order newest-first input', () {
    final view = buildForumIndexView(
      categories: categories,
      favoriteFidsOrdered: ['3', '1'],
    );
    expect(view.pinned.map((f) => f.fid).toList(), ['3', '1']);
  });

  test('flattenForumCategories maps nested fids', () {
    final map = flattenForumCategories(categories);
    expect(map['1']?.name, '外野');
    expect(map['c1']?.name, '分类一');
    expect(map['99']?.name, '独立版块');
  });
}
