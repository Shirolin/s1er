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
    typeName: 'NS',
  );

  Future<void> pumpCard(
    WidgetTester tester, {
    required ListDensity density,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsProvider.overrideWith(
            () => SettingsNotifier(
              initial: AppSettings(threadListDensity: density),
            ),
          ),
          readingRecordProvider(sampleThread.tid).overrideWithValue(null),
        ],
        child: wrapWithAppTheme(
          SizedBox(
            width: 400,
            child: ThreadCard(thread: sampleThread),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('standard density stacks category tag above title',
      (tester) async {
    await pumpCard(tester, density: ListDensity.standard);

    final tagTop = tester.getTopLeft(find.text('NS')).dy;
    final titleTop = tester.getTopLeft(find.text(sampleThread.subject)).dy;
    expect(titleTop, greaterThan(tagTop + 4));

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
      isFalse,
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
      ThreadCardDensityTokens.forDensity(ListDensity.compact).inlineProgress,
      isTrue,
    );
    expect(
      ThreadCardDensityTokens.forDensity(ListDensity.standard).inlineProgress,
      isFalse,
    );
  });

  testWidgets('compact density shows reading progress as meta badge',
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
          readingRecordProvider(sampleThread.tid).overrideWithValue(record),
        ],
        child: wrapWithAppTheme(
          SizedBox(
            width: 400,
            child: ThreadCard(thread: sampleThread),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('#4/6'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsNothing);
  });

  testWidgets('standard density keeps reading progress bar', (tester) async {
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
          readingRecordProvider(sampleThread.tid).overrideWithValue(record),
        ],
        child: wrapWithAppTheme(
          SizedBox(
            width: 400,
            child: ThreadCard(thread: sampleThread),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
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
            child: ThreadCard(thread: longTagThread),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('????'), findsOneWidget);
    expect(find.text('????????????'), findsNothing);
  });

  testWidgets('standard density keeps full category tag', (tester) async {
    final longTagThread = Thread(
      tid: '102',
      subject: '??',
      author: '??',
      authorId: '1',
      dateline: 1700000000,
      views: 100,
      replies: 5,
      fid: '4',
      typeName: '????????????',
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

    expect(find.text('????????????'), findsOneWidget);
  });
}
