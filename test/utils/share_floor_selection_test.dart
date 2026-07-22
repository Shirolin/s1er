import 'package:flutter_test/flutter_test.dart';
import 'package:s1er/config/constants.dart';
import 'package:s1er/models/post.dart';
import 'package:s1er/models/share_floor_data.dart';
import 'package:s1er/utils/share_floor_selection.dart';

Post _p(String pid, int floor) => Post.fromJson({
      'pid': pid,
      'message': 'm$pid',
      'author': 'a',
      'authorid': '1',
      'dbdateline': '1',
      'number': '$floor',
    });

void main() {
  test('toggle adds and removes by pid', () {
    var list = <ShareFloorData>[];
    list = ShareFloorSelection.toggle(
      current: list,
      post: _p('1', 1),
      displayFloor: 1,
    )!;
    expect(list.length, 1);

    list = ShareFloorSelection.toggle(
      current: list,
      post: _p('1', 1),
      displayFloor: 1,
    )!;
    expect(list, isEmpty);
  });

  test('toggle respects soft cap', () {
    var list = <ShareFloorData>[
      for (var i = 0; i < S1Constants.shareMaxSelectedFloors; i++)
        ShareFloorData(post: _p('$i', i + 1), displayFloor: i + 1),
    ];
    final blocked = ShareFloorSelection.toggle(
      current: list,
      post: _p('x', 99),
      displayFloor: 99,
    );
    expect(blocked, isNull);
  });

  test('sortedForExport orders by displayFloor', () {
    final floors = [
      ShareFloorData(post: _p('3', 3), displayFloor: 30),
      ShareFloorData(post: _p('1', 1), displayFloor: 10),
      ShareFloorData(post: _p('2', 2), displayFloor: 20),
    ];
    final sorted = ShareFloorSelection.sortedForExport(floors);
    expect(sorted.map((e) => e.post.pid).toList(), ['1', '2', '3']);
  });

  test('cross-page snapshot keeps displayFloor', () {
    final list = ShareFloorSelection.toggle(
      current: const [],
      post: _p('99', 5),
      displayFloor: 45,
    )!;
    expect(list.single.displayFloor, 45);
    expect(ShareFloorSelection.containsPid(list, '99'), isTrue);
  });
}
