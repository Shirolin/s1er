import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:s1er/models/reading_history_state.dart';
import 'package:s1er/models/reading_record.dart';
import 'package:s1er/providers/forum_name_provider.dart';
import 'package:s1er/providers/reading_history_provider.dart';
import 'package:s1er/screens/reading_history_screen.dart';
import 'package:s1er/theme/app_theme.dart';

class _FakeHistory extends ReadingHistoryNotifier {
  _FakeHistory(this.initial);

  final ReadingHistoryState initial;

  @override
  ReadingHistoryState build() => initial;
}

ReadingRecord _record({required int lastReadFloor, required int totalReplies}) {
  return ReadingRecord(
    tid: '2264749',
    subject: '游戏机架构讨论',
    author: 'someone',
    fid: '4',
    lastReadPage: 1,
    lastReadFloor: lastReadFloor,
    totalPages: 1,
    totalReplies: totalReplies,
    perPage: 40,
    lastReadAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
    firstReadAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
  );
}

Future<void> _pump(WidgetTester tester, ReadingHistoryState state) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        readingHistoryProvider.overrideWith(() => _FakeHistory(state)),
        // 版块名来自论坛列表接口，测试里不联网。
        fidToForumNameMapProvider.overrideWithValue({'4': '游戏论坛'}),
      ],
      child: MaterialApp(
        theme: AppTheme.lightTheme('purple'),
        home: const ReadingHistoryScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('exposes the row as a button instead of a progressbar',
      (tester) async {
    final handle = tester.ensureSemantics();
    await _pump(
      tester,
      ReadingHistoryState.fromRecords([
        _record(lastReadFloor: 12, totalReplies: 100),
      ]),
    );

    // 进度条只作装饰；不排除时整行会被读成 progressbar，楼层进度也被念成百分比。
    final row = find.descendant(
      of: find.byType(Card),
      matching: find.byType(InkWell),
    );
    final data = tester.getSemantics(row.first).getSemanticsData();
    expect(data.role, isNot(SemanticsRole.progressBar));
    expect(data.hasAction(SemanticsAction.tap), isTrue);
    expect(find.bySemanticsLabel(RegExp('游戏机架构讨论')), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('#12/101')), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('游戏论坛')), findsOneWidget);
    handle.dispose();
  });

  testWidgets('shows the empty state without history', (tester) async {
    await _pump(tester, ReadingHistoryState.empty);
    expect(find.text('暂无阅读记录'), findsOneWidget);
  });
}
