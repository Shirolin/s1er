import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:s1er/models/thread_open_intent.dart';
import 'package:s1er/providers/thread_open_intent_provider.dart';
import 'package:s1er/theme/app_theme.dart';
import 'package:s1er/widgets/thread_open_intent_scope.dart';

void main() {
  testWidgets('switching tid rebuilds the provider override scope',
      (tester) async {
    var tid = '100';
    late StateSetter setState;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme('purple'),
        home: StatefulBuilder(
          builder: (context, update) {
            setState = update;
            return ThreadOpenIntentScope(
              tid: tid,
              intent: ThreadOpenIntent.page(tid == '100' ? 1 : 2),
              child: Consumer(
                builder: (context, ref, _) {
                  final intent = ref.watch(threadOpenIntentProvider(tid));
                  return Text('$tid:${intent?.page}');
                },
              ),
            );
          },
        ),
      ),
    );

    expect(find.text('100:1'), findsOneWidget);

    setState(() => tid = '200');
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('200:2'), findsOneWidget);
  });
}
