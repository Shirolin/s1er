import 'package:flutter_test/flutter_test.dart';
import 'package:s1er/utils/semver.dart';

void main() {
  group('Semver', () {
    test('pads missing segments', () {
      expect(Semver.compare('1', '1.0.0'), 0);
      expect(Semver.compare('1.2', '1.2.0'), 0);
    });

    test('ignores build metadata', () {
      expect(Semver.compare('1.0.0+5', '1.0.0'), 0);
      expect(Semver.isLessThan('1.0.0+9', '1.0.1'), isTrue);
    });

    test('orders major minor patch', () {
      expect(Semver.isLessThan('1.0.0', '2.0.0'), isTrue);
      expect(Semver.isLessThan('1.0.0', '1.1.0'), isTrue);
      expect(Semver.isLessThan('1.0.0', '1.0.1'), isTrue);
      expect(Semver.isGreaterThan('1.2.3', '1.2.2'), isTrue);
    });

    test('rejects invalid', () {
      expect(Semver.tryParse(''), isNull);
      expect(Semver.tryParse('a.b.c'), isNull);
      expect(() => Semver.compare('1.0', 'nope'), throwsFormatException);
    });
  });
}
