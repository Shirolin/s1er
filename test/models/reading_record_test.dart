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
