import 'reading_record.dart';

/// 阅读历史 provider 状态：排序列表 + tid 索引。
class ReadingHistoryState {
  const ReadingHistoryState({
    required this.records,
    required this.byTid,
  });

  static const empty = ReadingHistoryState(records: [], byTid: {});

  final List<ReadingRecord> records;
  final Map<String, ReadingRecord> byTid;

  bool get isEmpty => records.isEmpty;

  bool get isNotEmpty => records.isNotEmpty;

  static ReadingHistoryState fromRecords(List<ReadingRecord> records) {
    return ReadingHistoryState(
      records: records,
      byTid: {for (final r in records) r.tid: r},
    );
  }
}
