import 'package:flutter_test/flutter_test.dart';
import 'package:s1_app/models/reading_record.dart';

ReadingRecord _make({
  int lastReadPage = 1,
  int totalPages = 1,
  int totalReplies = 0,
  int readCount = 1,
}) {
  return ReadingRecord(
    tid: '123',
    subject: '标题',
    author: 'author',
    fid: '4',
    lastReadPage: lastReadPage,
    lastReadFloor: 1,
    totalPages: totalPages,
    totalReplies: totalReplies,
    perPage: 40,
    lastReadAt: 1700000000000,
    firstReadAt: 1699999999000,
    readCount: readCount,
  );
}

void main() {
  group('ReadingRecord.progress', () {
    test('半程进度按页级计算', () {
      expect(_make(lastReadPage: 2, totalPages: 4).progress, 0.5);
    });

    test('进度被 clamp 到 [0,1]', () {
      expect(_make(lastReadPage: 9, totalPages: 4).progress, 1.0);
    });

    test('totalPages 为 0 时进度为 0', () {
      expect(_make(totalPages: 0).progress, 0.0);
    });
  });

  group('ReadingRecord.isFinished（页级，修正 0 回复 bug）', () {
    test('读到最后一页视为已读', () {
      expect(_make(lastReadPage: 4, totalPages: 4).isFinished, isTrue);
    });

    test('未到最后一页视为未读完', () {
      expect(_make(lastReadPage: 2, totalPages: 4).isFinished, isFalse);
    });

    test('0 回复单页帖首次进入即已读（v1.0 楼层级公式的 bug 已修）', () {
      final r = _make(lastReadPage: 1, totalPages: 1, totalReplies: 0);
      expect(r.isFinished, isTrue);
    });
  });

  group('ReadingRecord 相对实时页数', () {
    test('已读且无新页时 isFinishedAt 为 true', () {
      final r = _make(lastReadPage: 5, totalPages: 5);
      expect(r.isFinishedAt(5), isTrue);
      expect(r.hasNewPages(5), isFalse);
    });

    test('已读但页数增加后 hasNewPages 为 true', () {
      final r = _make(lastReadPage: 5, totalPages: 5);
      expect(r.isFinishedAt(7), isFalse);
      expect(r.hasNewPages(7), isTrue);
      expect(r.progressAt(7), closeTo(5 / 7, 0.001));
    });
  });

  group('ReadingRecord.resolveOpenPage', () {
    test('未读完续读到上次页', () {
      expect(_make(lastReadPage: 3, totalPages: 8).resolveOpenPage(8), 3);
    });

    test('已读无新回复落最后一页', () {
      expect(_make(lastReadPage: 5, totalPages: 5).resolveOpenPage(5), 5);
    });

    test('已读有新回复落原末页下一页', () {
      expect(_make(lastReadPage: 5, totalPages: 5).resolveOpenPage(7), 6);
    });

    test('仅读到第一页且未读完仍从第一页打开', () {
      expect(_make(lastReadPage: 1, totalPages: 4).resolveOpenPage(4), 1);
    });
  });

  group('ReadingRecord 序列化', () {
    test('toJson/fromJson 往返保持字段', () {
      final r = _make(lastReadPage: 3, totalPages: 5, readCount: 7);
      final restored = ReadingRecord.fromJson(r.toJson());
      expect(restored.tid, r.tid);
      expect(restored.lastReadPage, 3);
      expect(restored.totalPages, 5);
      expect(restored.perPage, 40);
      expect(restored.readCount, 7);
      expect(restored.firstReadAt, r.firstReadAt);
    });

    test('fromJson 容忍缺失字段', () {
      final r = ReadingRecord.fromJson({'tid': '9'});
      expect(r.tid, '9');
      expect(r.lastReadPage, 1);
      expect(r.totalPages, 1);
      expect(r.readCount, 1);
    });
  });
}
