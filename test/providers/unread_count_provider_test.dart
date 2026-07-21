import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:s1er/models/unread_count.dart';
import 'package:s1er/providers/unread_count_provider.dart';

void main() {
  group('UnreadCount model', () {
    test('fromJson parses string numbers correctly', () {
      final count = UnreadCount.fromJson({
        'newpm': '2',
        'newprompt': '5',
        'newmypost': '10',
      });
      expect(count.newpm, 2);
      expect(count.newprompt, 5);
      expect(count.newmypost, 10);
      expect(count.total, 17);
      expect(count.displayBadge, '17');
    });

    test('fromJson handles int and null gracefully', () {
      final count = UnreadCount.fromJson({
        'newpm': 1,
        'newprompt': null,
        'newmypost': 'invalid',
      });
      expect(count.newpm, 1);
      expect(count.newprompt, 0);
      expect(count.newmypost, 0);
      expect(count.total, 1);
      expect(count.displayBadge, '1');
    });

    test('displayBadge formats count greater than 99 as 99+', () {
      final count = UnreadCount.fromJson({
        'newpm': 50,
        'newprompt': 50,
        'newmypost': 1,
      });
      expect(count.total, 101);
      expect(count.displayBadge, '99+');
    });
  });

  group('UnreadCountNotifier', () {
    test('updateFromNotice updates state', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(unreadCountProvider), UnreadCount.zero);

      container.read(unreadCountProvider.notifier).updateFromNotice({
        'newpm': '1',
        'newprompt': '0',
        'newmypost': '0',
      });

      expect(
        container.read(unreadCountProvider),
        const UnreadCount(newpm: 1),
      );

      container.read(unreadCountProvider.notifier).clear();
      expect(container.read(unreadCountProvider), UnreadCount.zero);
    });
  });
}
