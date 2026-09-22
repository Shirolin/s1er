import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:s1er/providers/server_notice_provider.dart';

void main() {
  group('serverNoticeProvider', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
      addTearDown(container.dispose);
    });

    test('starts empty and shows first offered notice', () {
      expect(container.read(serverNoticeProvider), isNull);
      container.read(serverNoticeProvider.notifier).offer('维护公告');
      expect(container.read(serverNoticeProvider), '维护公告');
    });

    test('same notice is offered only once per session', () {
      final notifier = container.read(serverNoticeProvider.notifier);
      notifier.offer('维护公告');
      notifier.dismiss();
      expect(container.read(serverNoticeProvider), isNull);

      notifier.offer('维护公告');
      expect(container.read(serverNoticeProvider), isNull);
    });

    test('updated notice replaces the previous one', () {
      final notifier = container.read(serverNoticeProvider.notifier);
      notifier.offer('第一版公告');
      notifier.offer('第二版公告');
      expect(container.read(serverNoticeProvider), '第二版公告');
    });

    test('blank notice is ignored', () {
      container.read(serverNoticeProvider.notifier).offer('   ');
      expect(container.read(serverNoticeProvider), isNull);
    });
  });
}
