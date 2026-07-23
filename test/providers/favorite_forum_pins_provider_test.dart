import 'package:flutter_test/flutter_test.dart';
import 'package:s1er/models/favorite_item.dart';
import 'package:s1er/providers/favorite_forum_pins_provider.dart';
import 'package:s1er/services/api_service.dart';

class _FakeApiService extends Fake implements ApiService {
  _FakeApiService(this.pages);

  final Map<int, FavoriteListResult> pages;
  final calls = <int>[];

  @override
  Future<FavoriteListResult> getFavoriteList({
    required String uid,
    String? type,
    int page = 1,
  }) async {
    expect(type, 'forum');
    calls.add(page);
    return pages[page] ?? const FavoriteListResult(items: [], totalPages: 1);
  }
}

FavoriteItem _forum({
  required String id,
  required int dateline,
  String title = '',
}) {
  return FavoriteItem(
    favid: 'f$id',
    type: FavoriteType.forum,
    id: id,
    title: title.isEmpty ? 'Forum $id' : title,
    dateline: dateline,
  );
}

void main() {
  test('fetchAllFavoriteForums merges pages and sorts by dateline', () async {
    final api = _FakeApiService({
      1: FavoriteListResult(
        items: [
          _forum(id: '1', dateline: 100),
          _forum(id: '2', dateline: 300),
        ],
        currentPage: 1,
        totalPages: 2,
      ),
      2: FavoriteListResult(
        items: [
          _forum(id: '3', dateline: 200),
        ],
        currentPage: 2,
        totalPages: 2,
      ),
    });

    final items = await fetchAllFavoriteForums(api: api, uid: 'u1');

    expect(api.calls, [1, 2]);
    expect(items.map((e) => e.id).toList(), ['2', '3', '1']);
  });

  test('fetchAllFavoriteForums respects maxPages', () async {
    final api = _FakeApiService({
      1: FavoriteListResult(
        items: [_forum(id: '1', dateline: 1)],
        currentPage: 1,
        totalPages: 5,
      ),
      2: FavoriteListResult(
        items: [_forum(id: '2', dateline: 2)],
        currentPage: 2,
        totalPages: 5,
      ),
    });

    final items = await fetchAllFavoriteForums(
      api: api,
      uid: 'u1',
      maxPages: 2,
    );

    expect(api.calls, [1, 2]);
    expect(items, hasLength(2));
  });
}
