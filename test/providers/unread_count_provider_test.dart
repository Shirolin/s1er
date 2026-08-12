import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:s1er/models/notice_item.dart';
import 'package:s1er/models/unread_count.dart';
import 'package:s1er/providers/unread_count_provider.dart';

NoticeItem _notice({
  required String id,
  bool isNew = true,
}) {
  return NoticeItem(
    id: id,
    authorUid: '1',
    authorName: 'u',
    summary: '回复了您的帖子',
    dateline: 1,
    tid: '100',
    pid: '200',
    type: NoticeType.reply,
    isNew: isNew,
  );
}

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
    test('updateFromNotice updates state before list seed', () {
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

    test('unseeded server newmypost drives the badge', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(unreadCountProvider.notifier);

      notifier.updateFromNotice({
        'newpm': '0',
        'newprompt': '0',
        'newmypost': '1',
      });

      expect(
        container.read(unreadCountProvider),
        const UnreadCount(newmypost: 1),
      );
    });

    test('merge pending ids drives mypost; stale server 1 does not shrink', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(unreadCountProvider.notifier);

      notifier.updateFromNotice({
        'newpm': '0',
        'newprompt': '0',
        'newmypost': '1',
      });
      notifier.mergeMypostFromList([
        _notice(id: 'a'),
        _notice(id: 'b'),
      ]);

      expect(container.read(unreadCountProvider).newmypost, 2);

      notifier.updateFromNotice({
        'newpm': '0',
        'newprompt': '0',
        'newmypost': '1',
      });
      expect(container.read(unreadCountProvider).newmypost, 2);
    });

    test('markMypostRead clears pending; stale newmypost=1 stays off', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(unreadCountProvider.notifier);

      notifier.updateFromNotice({
        'newpm': '0',
        'newprompt': '0',
        'newmypost': '1',
      });
      notifier.mergeMypostFromList([
        _notice(id: 'a'),
        _notice(id: 'b'),
      ]);

      notifier.markMypostRead('a');
      expect(container.read(unreadCountProvider).newmypost, 1);

      notifier.markMypostRead('b');
      expect(container.read(unreadCountProvider).newmypost, 0);

      notifier.updateFromNotice({
        'newpm': '0',
        'newprompt': '0',
        'newmypost': '1',
      });
      expect(container.read(unreadCountProvider).newmypost, 0);
    });

    test('refresh with all new=0 does not drop untapped pending ids', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(unreadCountProvider.notifier);

      notifier.mergeMypostFromList([
        _notice(id: 'a'),
        _notice(id: 'b'),
      ]);
      expect(container.read(unreadCountProvider).newmypost, 2);

      notifier.mergeMypostFromList([
        _notice(id: 'a', isNew: false),
        _notice(id: 'b', isNew: false),
        _notice(id: 'c', isNew: false),
      ]);
      expect(container.read(unreadCountProvider).newmypost, 2);
    });

    test('rising-edge 0→1 after local clear re-lights server lamp', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(unreadCountProvider.notifier);

      notifier.updateFromNotice({
        'newpm': '0',
        'newprompt': '0',
        'newmypost': '1',
      });
      notifier.mergeMypostFromList([_notice(id: 'a')]);
      notifier.markMypostRead('a');
      expect(container.read(unreadCountProvider).newmypost, 0);

      notifier.updateFromNotice({
        'newpm': '0',
        'newprompt': '0',
        'newmypost': '0',
      });
      expect(container.read(unreadCountProvider).newmypost, 0);

      notifier.updateFromNotice({
        'newpm': '0',
        'newprompt': '0',
        'newmypost': '1',
      });
      expect(container.read(unreadCountProvider).newmypost, 1);
    });

    test('HTML-only tap seeds and clears server mypost lamp', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(unreadCountProvider.notifier);

      notifier.updateFromNotice({
        'newpm': '0',
        'newprompt': '0',
        'newmypost': '1',
      });
      expect(container.read(unreadCountProvider).newmypost, 1);

      // No merge (HTML has no isNew); tap still clears for this session.
      notifier.markMypostRead('18830194');
      expect(container.read(unreadCountProvider).newmypost, 0);

      notifier.updateFromNotice({
        'newpm': '0',
        'newprompt': '0',
        'newmypost': '1',
      });
      expect(container.read(unreadCountProvider).newmypost, 0);
    });

    test('merge with no isNew does not seed or clear server lamp', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(unreadCountProvider.notifier);

      notifier.updateFromNotice({
        'newpm': '0',
        'newprompt': '0',
        'newmypost': '1',
      });
      notifier.mergeMypostFromList([
        _notice(id: 'a', isNew: false),
      ]);

      expect(container.read(unreadCountProvider).newmypost, 1);
    });

    test('clear resets pending and seeded session state', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(unreadCountProvider.notifier);

      notifier.updateFromNotice({
        'newpm': '1',
        'newprompt': '1',
        'newmypost': '1',
      });
      notifier.mergeMypostFromList([_notice(id: 'a')]);
      notifier.clear();

      expect(container.read(unreadCountProvider), UnreadCount.zero);

      notifier.updateFromNotice({
        'newpm': '0',
        'newprompt': '0',
        'newmypost': '1',
      });
      expect(container.read(unreadCountProvider).newmypost, 1);
    });
  });
}
