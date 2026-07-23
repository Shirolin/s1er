import 'package:flutter_test/flutter_test.dart';
import 'package:s1er/models/list_density.dart';

void main() {
  group('ListDensity', () {
    test('fromStored maps known values and defaults unknown', () {
      expect(ListDensity.fromStored('standard'), ListDensity.standard);
      expect(ListDensity.fromStored('compact'), ListDensity.compact);
      expect(ListDensity.fromStored(null), ListDensity.standard);
      expect(ListDensity.fromStored('weird'), ListDensity.standard);
    });

    test('storageKey round-trips', () {
      for (final density in ListDensity.values) {
        expect(ListDensity.fromStored(density.storageKey), density);
      }
    });
  });
}
