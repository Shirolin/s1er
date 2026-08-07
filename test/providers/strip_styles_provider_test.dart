import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:s1er/providers/strip_styles_provider.dart';

void main() {
  group('StripStylesSessionNotifier', () {
    test('starts empty and toggles per pid', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(strippedStylePidsProvider.notifier);

      expect(container.read(strippedStylePidsProvider), isEmpty);
      notifier.toggle('123');
      expect(container.read(strippedStylePidsProvider), const {'123'});
      notifier.toggle('123');
      expect(container.read(strippedStylePidsProvider), isEmpty);
    });

    test('add/remove/isStripped', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(strippedStylePidsProvider.notifier);

      expect(notifier.isStripped('1'), isFalse);
      notifier.add('1');
      expect(notifier.isStripped('1'), isTrue);
      // add is idempotent.
      notifier.add('1');
      expect(container.read(strippedStylePidsProvider), const {'1'});
      notifier.remove('1');
      expect(notifier.isStripped('1'), isFalse);
      // remove of unknown pid is a no-op.
      notifier.remove('1');
      expect(container.read(strippedStylePidsProvider), isEmpty);
    });

    test('ignores empty pid', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(strippedStylePidsProvider.notifier).add('');
      expect(container.read(strippedStylePidsProvider), isEmpty);
    });

    test('clear resets the whole session set', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(strippedStylePidsProvider.notifier);

      notifier.add('1');
      notifier.add('2');
      expect(container.read(strippedStylePidsProvider), const {'1', '2'});
      notifier.clear();
      expect(container.read(strippedStylePidsProvider), isEmpty);
    });
  });
}
