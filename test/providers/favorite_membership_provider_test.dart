import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:s1_app/models/favorite_item.dart';
import 'package:s1_app/providers/favorite_membership_provider.dart';

void main() {
  group('FavoriteMembershipState', () {
    test('tracks favorited keys and favids', () {
      const state = FavoriteMembershipState(
        keys: {'thread:123', 'forum:4'},
        favids: {'thread:123': '1001', 'forum:4': '2001'},
      );

      expect(state.isFavorited(FavoriteType.thread, '123'), isTrue);
      expect(state.isFavorited(FavoriteType.thread, '999'), isFalse);
      expect(state.favidFor(FavoriteType.forum, '4'), '2001');
    });
  });

  group('FavoriteMembershipNotifier', () {
    test('untrack removes membership entry', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(favoriteMembershipProvider.notifier);
      notifier.state = const FavoriteMembershipState(
        keys: {'thread:1'},
        favids: {'thread:1': '9'},
      );

      notifier.untrack(
        const FavoriteItem(
          favid: '9',
          type: FavoriteType.thread,
          id: '1',
          title: 't',
          dateline: 0,
        ),
      );

      final state = container.read(favoriteMembershipProvider);
      expect(state.keys, isEmpty);
      expect(state.favids, isEmpty);
    });
  });
}
