import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:s1er/models/list_density.dart';
import 'package:s1er/models/reading_record.dart';
import 'package:s1er/models/thread.dart';
import 'package:s1er/providers/reading_history_provider.dart';
import 'package:s1er/providers/settings_provider.dart';
import 'package:s1er/widgets/thread_card.dart';

import '../helpers/test_theme.dart';

void main() {
  final sampleThread = Thread(
    tid: '100',
    subject: '???????????????????????????',
    author: '??',
    authorId: '1',
    dateline: 1700000000,
    views: 100,
    replies: 5,
    fid: '4',
    typeId: '1',
    typeName: 'NS',
  );

  Future<void> pumpCard(
    WidgetTester tester, {
    required ListDensity density,
    Thread? thread,
    String? selectedTypeId,
    ThreadTypeFilterCallback? onTypeFilter,
    ReadingRecord? record,
  }) async {
    final t = thread ?? sampleThread;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsProvider.overrideWith(
            () => SettingsNotifier(
              initial: AppSettings(threadListDensity: density),
            ),
          ),
          readingRecordProvider(t.tid).overrideWithValue(record),
        ],
        child: wrapWithAppTheme(
          SizedBox(
            width: 400,
            child: ThreadCard(
              thread: t,
              selectedTypeId: selectedTypeId,
              onTypeFilter: onTypeFilter,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('standard density keeps category tag on title row',
      (tester) async {
    await pumpCard(tester, density: ListDensity.standard);

    final tagTop = tester.getTopLeft(find.text('NS')).dy;
    final titleTop = tester.getTopLeft(find.text(sampleThread.subject)).dy;
    expect((tagTop - titleTop).abs(), lessThan(8));

    final text = tester.widget<Text>(find.text(sampleThread.subject));
    expect(text.maxLines, 2);
  });

  testWidgets('compact density keeps category tag inline with title',
      (tester) async {
    await pumpCard(tester, density: ListDensity.compact);

    final tagCenter = tester.getCenter(find.text('NS')).dy;
    final titleCenter = tester.getCenter(find.text(sampleThread.subject)).dy;
    expect((tagCenter - titleCenter).abs(), lessThan(12));

    final text = tester.widget<Text>(find.text(sampleThread.subject));
    expect(text.maxLines, 1);
  });

  testWidgets('switching density rebuilds layout', (tester) async {
    final container = ProviderContainer(
      overrides: [
        settingsProvider.overrideWith(
          () => SettingsNotifier(
            initial: const AppSettings(
              threadListDensity: ListDensity.standard,
            ),
          ),
        ),
        readingRecordProvider(sampleThread.tid).overrideWithValue(null),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: wrapWithAppTheme(
          SizedBox(
            width: 400,
            child: ThreadCard(thread: sampleThread),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      tester.widget<Text>(find.text(sampleThread.subject)).maxLines,
      2,
    );

    container
        .read(settingsProvider.notifier)
        .setThreadListDensity(ListDensity.compact);
    await tester.pumpAndSettle();

    expect(
      tester.widget<Text>(find.text(sampleThread.subject)).maxLines,
      1,
    );
  });

  test('ThreadCardDensityTokens map density modes', () {
    expect(
      ThreadCardDensityTokens.forDensity(ListDensity.standard).inlineTag,
      isTrue,
    );
    expect(
      ThreadCardDensityTokens.forDensity(ListDensity.compact).inlineTag,
      isTrue,
    );
    expect(
      ThreadCardDensityTokens.forDensity(ListDensity.compact).titleMaxLines,
      1,
    );
    expect(
      ThreadCardDensityTokens.forDensity(ListDensity.compact).showProgressBar,
      isFalse,
    );
    expect(
      ThreadCardDensityTokens.forDensity(ListDensity.standard).showProgressBar,
      isTrue,
    );
    expect(
      ThreadCardDensityTokens.forDensity(ListDensity.compact).showPageChip,
      isFalse,
    );
    expect(
      ThreadCardDensityTokens.forDensity(ListDensity.standard).showPageChip,
      isTrue,
    );
  });

  testWidgets('compact density hides page ActionChip', (tester) async {
    final multiPageThread = sampleThread.copyWith(replies: 5000);
    await pumpCard(
      tester,
      density: ListDensity.compact,
      thread: multiPageThread,
    );

    expect(find.byType(ActionChip), findsNothing);
  });

  testWidgets('standard density keeps outlined page count button',
      (tester) async {
    final multiPageThread = sampleThread.copyWith(replies: 5000);
    await pumpCard(
      tester,
      density: ListDensity.standard,
      thread: multiPageThread,
    );

    expect(find.byType(ActionChip), findsNothing);
    final pageText = find.textContaining('页');
    expect(pageText, findsOneWidget);
    final pageMaterial = tester.widget<Material>(
      find.ancestor(of: pageText, matching: find.byType(Material)).first,
    );
    expect(pageMaterial.color, Colors.transparent);
    expect(
      find.ancestor(of: pageText, matching: find.byType(InkWell)),
      findsWidgets,
    );
  });

  testWidgets('compact density merges reading progress into reply meta',
      (tester) async {
    final record = ReadingRecord(
      tid: sampleThread.tid,
      subject: sampleThread.subject,
      author: sampleThread.author,
      fid: sampleThread.fid,
      lastReadPage: 1,
      lastReadFloor: 4,
      totalPages: 1,
      totalReplies: 5,
      perPage: 40,
      lastReadAt: 1,
      firstReadAt: 1,
    );

    await pumpCard(
      tester,
      density: ListDensity.compact,
      record: record,
    );

    expect(find.textContaining('#4'), findsOneWidget);
    expect(find.textContaining('#4/'), findsNothing);
    expect(find.byType(LinearProgressIndicator), findsNothing);
  });

  testWidgets('standard density hides progress bar when finished',
      (tester) async {
    final record = ReadingRecord(
      tid: sampleThread.tid,
      subject: sampleThread.subject,
      author: sampleThread.author,
      fid: sampleThread.fid,
      lastReadPage: 1,
      lastReadFloor: 6,
      totalPages: 1,
      totalReplies: 5,
      perPage: 40,
      lastReadAt: 1,
      firstReadAt: 1,
    );

    await pumpCard(
      tester,
      density: ListDensity.standard,
      record: record,
    );

    expect(find.textContaining('已读'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsNothing);
  });

  testWidgets('standard density shows 2px progress bar while reading',
      (tester) async {
    final record = ReadingRecord(
      tid: sampleThread.tid,
      subject: sampleThread.subject,
      author: sampleThread.author,
      fid: sampleThread.fid,
      lastReadPage: 1,
      lastReadFloor: 4,
      totalPages: 1,
      totalReplies: 5,
      perPage: 40,
      lastReadAt: 1,
      firstReadAt: 1,
    );

    await pumpCard(
      tester,
      density: ListDensity.standard,
      record: record,
    );

    expect(find.textContaining('#4'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    final bar = tester.widget<LinearProgressIndicator>(
      find.byType(LinearProgressIndicator),
    );
    expect(bar.minHeight, 2);
  });

  testWidgets('reply count uses full number not abbreviation', (tester) async {
    final busyThread = sampleThread.copyWith(replies: 1723);
    await pumpCard(tester, density: ListDensity.compact, thread: busyThread);

    expect(find.textContaining('1723'), findsOneWidget);
    expect(find.textContaining('1,723'), findsNothing);
    expect(find.textContaining('1.7k'), findsNothing);
  });

  testWidgets('category FilterChip toggles type filter', (tester) async {
    String? filtered;
    await pumpCard(
      tester,
      density: ListDensity.standard,
      selectedTypeId: null,
      onTypeFilter: (id) => filtered = id,
    );

    await tester.tap(find.widgetWithText(FilterChip, 'NS'));
    await tester.pumpAndSettle();
    expect(filtered, '1');

    await pumpCard(
      tester,
      density: ListDensity.standard,
      selectedTypeId: '1',
      onTypeFilter: (id) => filtered = id,
    );

    await tester.tap(find.widgetWithText(FilterChip, 'NS'));
    await tester.pumpAndSettle();
    expect(filtered, isNull);
  });

  testWidgets('compact density truncates long category tags to 4 chars',
      (tester) async {
    final longTagThread = Thread(
      tid: '101',
      subject: '???????',
      author: '??',
      authorId: '1',
      dateline: 1700000000,
      views: 100,
      replies: 5,
      fid: '4',
      typeId: '2',
      typeName: '????????????',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsProvider.overrideWith(
            () => SettingsNotifier(
              initial: const AppSettings(
                threadListDensity: ListDensity.compact,
              ),
            ),
          ),
          readingRecordProvider(longTagThread.tid).overrideWithValue(null),
        ],
        child: wrapWithAppTheme(
          SizedBox(
            width: 400,
            child: ThreadCard(
              thread: longTagThread,
              onTypeFilter: (_) {},
              selectedTypeId: null,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('????'), findsOneWidget);
    expect(find.text('????????????'), findsNothing);
  });

  testWidgets('sticky thread uses primaryContainer and pin icon',
      (tester) async {
    final stickyThread = sampleThread.copyWith(displayOrder: 1);
    await pumpCard(
      tester,
      density: ListDensity.standard,
      thread: stickyThread,
    );

    final card = tester.widget<Card>(find.byType(Card));
    final scheme = Theme.of(tester.element(find.byType(Card))).colorScheme;
    expect(card.color, scheme.primaryContainer);
    expect(find.byIcon(Icons.push_pin), findsOneWidget);
    expect(find.textContaining('置顶'), findsNothing);
  });

  testWidgets('standard density truncates long category tags to 4 chars',
      (tester) async {
    final longTagThread = Thread(
      tid: '102',
      subject: 'subject',
      author: 'author',
      authorId: '1',
      dateline: 1700000000,
      views: 100,
      replies: 5,
      fid: '4',
      typeName: '青黑无脑不要游戏只求一战',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsProvider.overrideWith(
            () => SettingsNotifier(
              initial: const AppSettings(
                threadListDensity: ListDensity.standard,
              ),
            ),
          ),
          readingRecordProvider(longTagThread.tid).overrideWithValue(null),
        ],
        child: wrapWithAppTheme(
          SizedBox(
            width: 400,
            child: ThreadCard(thread: longTagThread),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('青黑无脑'), findsOneWidget);
    expect(find.text('青黑无脑不要游戏只求一战'), findsNothing);
  });
}
