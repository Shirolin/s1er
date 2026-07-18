import 'package:flutter_test/flutter_test.dart';
import 'package:s1er/models/blacklist_record.dart';

void main() {
  group('BlacklistRecord.normalizeScopes', () {
    test('keeps known scopes in order and drops unknowns', () {
      expect(
        BlacklistRecord.normalizeScopes(
          ['pm', 'thread', 'nope', 'post', 'thread'],
        ),
        ['pm', 'thread', 'post'],
      );
    });

    test('trims and ignores empty values', () {
      expect(
        BlacklistRecord.normalizeScopes([' thread ', '', null, 'post']),
        ['thread', 'post'],
      );
    });
  });

  group('BlacklistRecord.fromJson', () {
    test('parses fields and normalizes scope', () {
      final entry = BlacklistRecord.fromJson({
        'uid': '42',
        'username': 'alice',
        'createdAt': 100,
        'reason': 'spam',
        'scope': ['thread', 'evil', 'post'],
      });
      expect(entry.uid, '42');
      expect(entry.username, 'alice');
      expect(entry.createdAt, 100);
      expect(entry.reason, 'spam');
      expect(entry.scope, ['thread', 'post']);
      expect(entry.hasScope(BlacklistRecord.scopeThread), isTrue);
      expect(entry.hasScope(BlacklistRecord.scopePm), isFalse);
    });
  });
}
