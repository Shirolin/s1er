import 'package:flutter_test/flutter_test.dart';
import 'package:s1er/utils/daily_attendance_store.dart';

void main() {
  group('DailyAttendanceStore', () {
    test('formatDate uses local calendar day', () {
      expect(
        DailyAttendanceStore.formatDate(DateTime(2026, 7, 16, 23, 59)),
        '2026-07-16',
      );
      expect(
        DailyAttendanceStore.formatDate(DateTime(2026, 1, 5)),
        '2026-01-05',
      );
    });

    test('parse rejects invalid payloads', () {
      expect(DailyAttendanceStore.parse(null), isNull);
      expect(DailyAttendanceStore.parse('x'), isNull);
      expect(
        DailyAttendanceStore.parse({'uid': '', 'date': '2026-07-16'}),
        isNull,
      );
      expect(DailyAttendanceStore.parse({'uid': '1', 'date': ''}), isNull);
    });

    test('matches only same uid and same local day', () {
      final now = DateTime(2026, 7, 16, 10);
      final raw = DailyAttendanceStore.payload(uid: '9', now: now);

      expect(
        DailyAttendanceStore.matches(raw: raw, uid: '9', now: now),
        isTrue,
      );
      expect(
        DailyAttendanceStore.matches(raw: raw, uid: '8', now: now),
        isFalse,
      );
      expect(
        DailyAttendanceStore.matches(
          raw: raw,
          uid: '9',
          now: DateTime(2026, 7, 17),
        ),
        isFalse,
      );
    });
  });
}
