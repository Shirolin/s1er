import 'package:flutter_test/flutter_test.dart';
import 'package:s1er/models/reading_record.dart';

ReadingRecord _make({
  int lastReadPage = 1,
  int lastReadFloor = 1,
  int totalPages = 1,
  int totalReplies = 0,
  int perPage = 40,
  int readCount = 1,
}) {
  return ReadingRecord(
    tid: '123',
    subject: '标题',
    author: 'author',
    fid: '4',
    lastReadPage: lastReadPage,
    lastReadFloor: lastReadFloor,
    totalPages: totalPages,
    totalReplies: totalReplies,
    perPage: perPage,
    lastReadAt: 1700000000000,
    firstReadAt: 1699999999000,
    readCount: readCount,
  );
}

void main() {
  group('ReadingRecord.progress（楼级）', () {
    test('半程进度按楼级计算', () {
      expect(
        _make(lastReadFloor: 100, totalReplies: 199).progress,
        0.5,
      );
    });

    test('进度被 clamp 到 [0,1]', () {
      expect(
        _make(lastReadFloor: 250, totalReplies: 199).progress,
        1.0,
      );
    });

    test('totalPosts 为 0 时进度为 0（防御）', () {
      // totalReplies + 1 恒 >= 1；用负回复数防御性覆盖
      expect(_make(lastReadFloor: 0, totalReplies: -1).progress, 0.0);
    });
  });

  group('ReadingRecord.isFinished（楼级）', () {
    test('读到最后一楼视为已读', () {
      expect(
        _make(lastReadFloor: 200, totalReplies: 199).isFinished,
        isTrue,
      );
    });

    test('未到最后一楼视为未读完', () {
      expect(
        _make(lastReadFloor: 80, totalReplies: 199).isFinished,
        isFalse,
      );
    });

    test('0 回复单页帖读到主楼即已读', () {
      final r = _make(lastReadFloor: 1, totalReplies: 0);
      expect(r.isFinished, isTrue);
      expect(r.totalPosts, 1);
    });

    test('末页只读一半不视为已读（页级误判的修正）', () {
      // 第 5/5 页，但只读到该页中间楼
      final r = _make(
        lastReadPage: 5,
        lastReadFloor: 180,
        totalPages: 5,
        totalReplies: 199,
      );
      expect(r.isFinished, isFalse);
      expect(r.progress, closeTo(180 / 200, 0.001));
    });
  });

  group('ReadingRecord 相对实时回复数', () {
    test('已读且无新回复时 isFinishedAt 为 true', () {
      final r = _make(lastReadFloor: 200, totalReplies: 199);
      expect(r.isFinishedAt(199), isTrue);
      expect(r.hasNewReplies(199), isFalse);
    });

    test('已读但回复增加后 hasNewReplies 为 true', () {
      final r = _make(lastReadFloor: 200, totalReplies: 199);
      expect(r.isFinishedAt(279), isFalse);
      expect(r.hasNewReplies(279), isTrue);
      expect(r.progressAt(279), closeTo(200 / 280, 0.001));
    });
  });

  group('ReadingRecord.resolveOpenPage（由楼推页）', () {
    test('未读完续读到上次楼所在页', () {
      expect(
        _make(
          lastReadFloor: 85,
          totalPages: 8,
          totalReplies: 319,
        ).resolveOpenPage(319),
        3,
      );
    });

    test('已读无新回复落最后一页', () {
      expect(
        _make(
          lastReadFloor: 200,
          totalPages: 5,
          totalReplies: 199,
        ).resolveOpenPage(199),
        5,
      );
    });

    test('已读有新回复落首个未读楼所在页', () {
      expect(
        _make(
          lastReadFloor: 200,
          totalPages: 5,
          totalReplies: 199,
        ).resolveOpenPage(279),
        6,
      );
    });

    test('仅读到第一页楼层仍从第一页打开', () {
      expect(
        _make(
          lastReadFloor: 10,
          totalPages: 4,
          totalReplies: 159,
        ).resolveOpenPage(159),
        1,
      );
    });
  });

  group('pageForFloor', () {
    test('maps absolute floor to 1-based page', () {
      expect(pageForFloor(1, perPage: 40), 1);
      expect(pageForFloor(40, perPage: 40), 1);
      expect(pageForFloor(41, perPage: 40), 2);
      expect(pageForFloor(85, perPage: 40), 3);
    });
  });

  group('ReadingRecord 序列化', () {
    test('toJson/fromJson 往返保持字段', () {
      final r = _make(
        lastReadPage: 3,
        lastReadFloor: 85,
        totalPages: 5,
        totalReplies: 199,
        readCount: 7,
      );
      final restored = ReadingRecord.fromJson(r.toJson());
      expect(restored.tid, r.tid);
      expect(restored.lastReadPage, 3);
      expect(restored.lastReadFloor, 85);
      expect(restored.totalPages, 5);
      expect(restored.totalReplies, 199);
      expect(restored.perPage, 40);
      expect(restored.readCount, 7);
      expect(restored.firstReadAt, r.firstReadAt);
    });

    test('fromJson 容忍缺失字段', () {
      final r = ReadingRecord.fromJson({'tid': '9'});
      expect(r.tid, '9');
      expect(r.lastReadPage, 1);
      expect(r.lastReadFloor, 1);
      expect(r.totalPages, 1);
      expect(r.readCount, 1);
    });
  });
}
