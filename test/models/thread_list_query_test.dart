import 'package:flutter_test/flutter_test.dart';
import 'package:s1er/models/thread_list_query.dart';

void main() {
  group('ThreadListQuery.toForumDisplayParams', () {
    test('default query emits no filter params', () {
      expect(ThreadListQuery.defaults.toForumDisplayParams(), isEmpty);
      expect(ThreadListQuery.defaults.isDefault, isTrue);
      expect(ThreadListSortPreset.all.label, '全部主题');
    });

    test('latest without typeId', () {
      const query = ThreadListQuery(preset: ThreadListSortPreset.latest);
      expect(query.toForumDisplayParams(), {
        'filter': 'lastpost',
        'orderby': 'lastpost',
      });
      expect(query.preset.isPrimaryChip, isTrue);
    });

    test('newest (发帖时间) is more-menu sort only', () {
      const query = ThreadListQuery(preset: ThreadListSortPreset.newest);
      expect(query.toForumDisplayParams(), {
        'filter': 'author',
        'orderby': 'dateline',
      });
      expect(query.preset.isPrimaryChip, isFalse);
      expect(query.moreChipSelected, isTrue);
      expect(threadListMoreSortPresets, contains(ThreadListSortPreset.newest));
      expect(
        threadListPrimaryPresets,
        isNot(contains(ThreadListSortPreset.newest)),
      );
    });

    test('heat without typeId', () {
      const query = ThreadListQuery(preset: ThreadListSortPreset.heat);
      expect(query.toForumDisplayParams(), {
        'filter': 'heat',
        'orderby': 'heats',
      });
    });

    test('hot without typeId', () {
      const query = ThreadListQuery(preset: ThreadListSortPreset.hot);
      expect(query.toForumDisplayParams(), {'filter': 'hot'});
    });

    test('digest without typeId', () {
      const query = ThreadListQuery(preset: ThreadListSortPreset.digest);
      expect(query.toForumDisplayParams(), {
        'filter': 'digest',
        'digest': '1',
      });
    });

    test('replies and views without typeId', () {
      expect(
        const ThreadListQuery(preset: ThreadListSortPreset.replies)
            .toForumDisplayParams(),
        {'filter': 'reply', 'orderby': 'replies'},
      );
      expect(
        const ThreadListQuery(preset: ThreadListSortPreset.views)
            .toForumDisplayParams(),
        {'filter': 'reply', 'orderby': 'views'},
      );
    });

    test('time window alone uses dateline filter and lastpost', () {
      const query = ThreadListQuery(datelineSeconds: 86400);
      expect(query.toForumDisplayParams(), {
        'filter': 'dateline',
        'dateline': '86400',
        'orderby': 'lastpost',
      });
      expect(query.isDefault, isFalse);
      expect(query.moreChipSelected, isTrue);
    });

    test('time window with newest keeps author filter for post-time cutoff',
        () {
      const query = ThreadListQuery(
        preset: ThreadListSortPreset.newest,
        datelineSeconds: 604800,
      );
      expect(query.toForumDisplayParams(), {
        'filter': 'author',
        'orderby': 'dateline',
        'dateline': '604800',
      });
    });

    test('one-day newest is post-time within 24h', () {
      const query = ThreadListQuery(
        preset: ThreadListSortPreset.newest,
        datelineSeconds: 86400,
      );
      expect(query.toForumDisplayParams(), {
        'filter': 'author',
        'orderby': 'dateline',
        'dateline': '86400',
      });
    });

    test('time window with latest uses lastpost orderby', () {
      const query = ThreadListQuery(
        preset: ThreadListSortPreset.latest,
        datelineSeconds: 86400,
      );
      expect(query.toForumDisplayParams(), {
        'filter': 'dateline',
        'dateline': '86400',
        'orderby': 'lastpost',
      });
    });

    test('time window with replies keeps reply filter', () {
      const query = ThreadListQuery(
        preset: ThreadListSortPreset.replies,
        datelineSeconds: 86400,
      );
      expect(query.toForumDisplayParams(), {
        'filter': 'reply',
        'orderby': 'replies',
        'dateline': '86400',
      });
    });

    test('typeId locks filter=typeid and appends extras', () {
      const query = ThreadListQuery(preset: ThreadListSortPreset.heat);
      expect(query.toForumDisplayParams(typeId: '8'), {
        'filter': 'typeid',
        'typeid': '8',
        'orderby': 'heats',
      });
    });

    test('typeId with digest and time appends without overriding filter', () {
      const query = ThreadListQuery(
        preset: ThreadListSortPreset.digest,
        datelineSeconds: 2592000,
      );
      expect(query.toForumDisplayParams(typeId: '12'), {
        'filter': 'typeid',
        'typeid': '12',
        'digest': '1',
        'dateline': '2592000',
      });
    });

    test('typeId with newest does not set filter=author', () {
      const query = ThreadListQuery(preset: ThreadListSortPreset.newest);
      expect(query.toForumDisplayParams(typeId: '3'), {
        'filter': 'typeid',
        'typeid': '3',
        'orderby': 'dateline',
      });
    });

    test('three-month option uses Discuz 7948800', () {
      expect(threadListTimeOptions.last.seconds, 7948800);
      expect(threadListTimeOptions.last.label, '三个月');
    });
  });
}
