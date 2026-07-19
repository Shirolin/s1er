import 'package:flutter_test/flutter_test.dart';
import 'package:s1er/utils/compose_message_draft.dart';

void main() {
  group('ComposeMessageDraft.entryKey', () {
    test('uses tid alone when reppost empty', () {
      expect(ComposeMessageDraft.entryKey(tid: '100'), '100');
      expect(ComposeMessageDraft.entryKey(tid: '100', reppost: ''), '100');
      expect(ComposeMessageDraft.entryKey(tid: '100', reppost: '  '), '100');
    });

    test('joins tid and reppost', () {
      expect(
        ComposeMessageDraft.entryKey(tid: '100', reppost: '42'),
        '100:42',
      );
    });
  });

  group('ComposeMessageDraft store codec', () {
    test('parseStore ignores non-map entries', () {
      final parsed = ComposeMessageDraft.parseStore({
        '100': {'message': 'hi', 'updatedAt': 't'},
        'bad': 'x',
      });
      expect(parsed.keys, ['100']);
      expect(parsed['100']?['message'], 'hi');
    });

    test('readMessage returns null for empty', () {
      final drafts = ComposeMessageDraft.parseStore({
        '100': {'message': '  ', 'updatedAt': 't'},
      });
      expect(ComposeMessageDraft.readMessage(drafts, '100'), isNull);
    });

    test('upsert and removeEntry round-trip', () {
      var drafts = <String, Map<String, Object?>>{};
      drafts = ComposeMessageDraft.upsert(
        drafts,
        '100:42',
        'hello',
        updatedAt: DateTime.utc(2026, 7, 14),
      );
      expect(ComposeMessageDraft.readMessage(drafts, '100:42'), 'hello');
      expect(drafts['100:42']?['updatedAt'], '2026-07-14T00:00:00.000Z');

      drafts = ComposeMessageDraft.removeEntry(drafts, '100:42');
      expect(ComposeMessageDraft.toStoreValue(drafts), isNull);
    });

    test('upsert empty message removes entry', () {
      var drafts = ComposeMessageDraft.upsert({}, '100', 'hello');
      drafts = ComposeMessageDraft.upsert(drafts, '100', '  ');
      expect(ComposeMessageDraft.toStoreValue(drafts), isNull);
    });
  });
}
