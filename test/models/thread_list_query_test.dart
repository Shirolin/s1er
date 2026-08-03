import 'package:flutter_test/flutter_test.dart';
import 'package:s1er/models/thread_list_query.dart';

void main() {
  group('ThreadListQuery.toForumDisplayParams', () {
    test('default query emits no filter params', () {
      expect(ThreadListQuery.defaults.toForumDisplayParams(), isEmpty);
      expect(ThreadListQuery.defaults.isDefault, isTrue);
    });

    test('newest without typeId', () {
      const query = ThreadListQuery(preset: ThreadListSortPreset.newest);
      expect(query.toForumDisplayParams(), {
        'filter': 'author',
        'orderby': 'dateline',
      });
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

    test('time window with newest keeps orderby dateline', () {
      const query = ThreadListQuery(
        preset: ThreadListSortPreset.newest,
        datelineSeconds: 604800,
      );
      expect(query.toForumDisplayParams(), {
        'filter': 'dateline',
        'dateline': '604800',
        'orderby': 'dateline',
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
