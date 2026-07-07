import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:s1_app/services/formhash_service.dart';

void main() {
  group('FormhashNotifier', () {
    test('initial state is empty string', () {
      final container = ProviderContainer();
      expect(container.read(formhashProvider), '');
    });

    test('update sets formhash', () {
      final container = ProviderContainer();
      container.read(formhashProvider.notifier).update('abc123');
      expect(container.read(formhashProvider), 'abc123');
    });

    test('update ignores null and empty', () {
      final container = ProviderContainer();
      container.read(formhashProvider.notifier).update('abc123');
      container.read(formhashProvider.notifier).update(null);
      expect(container.read(formhashProvider), 'abc123');
      container.read(formhashProvider.notifier).update('');
      expect(container.read(formhashProvider), 'abc123');
    });

    test('clear resets formhash', () {
      final container = ProviderContainer();
      container.read(formhashProvider.notifier).update('abc123');
      container.read(formhashProvider.notifier).clear();
      expect(container.read(formhashProvider), '');
    });
  });
}
