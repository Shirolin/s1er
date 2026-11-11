import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:s1er/providers/forum_name_provider.dart';
import 'package:s1er/providers/settings_provider.dart';
import 'package:s1er/screens/hidden_forums_screen.dart';
import 'package:s1er/theme/app_theme.dart';

Widget _wrap({
  required Set<String> hidden,
  Map<String, String> names = const {},
}) {
  return ProviderScope(
    overrides: [
      settingsProvider.overrideWith(
        () => SettingsNotifier(initial: AppSettings(hiddenForums: hidden)),
      ),
      fidToForumNameMapProvider.overrideWithValue(names),
    ],
    child: MaterialApp(
      theme: AppTheme.lightTheme('sand'),
      home: const HiddenForumsScreen(),
    ),
  );
}

void main() {
  testWidgets('lists hidden forums with names and fid fallback',
      (tester) async {
    await tester.pumpWidget(
      _wrap(hidden: {'2', '17'}, names: {'17': '影视区'}),
    );
    await tester.pump();

    expect(find.text('已屏蔽版块'), findsOneWidget);
    expect(find.text('影视区'), findsOneWidget);
    expect(find.text('版块 #2'), findsOneWidget);
    expect(find.text('取消屏蔽'), findsNWidgets(2));
  });

  testWidgets('unhide removes one forum', (tester) async {
    await tester.pumpWidget(
      _wrap(hidden: {'2', '17'}, names: {'2': '游戏区', '17': '影视区'}),
    );
    await tester.pump();

    await tester.tap(find.text('取消屏蔽').first);
    await tester.pump();

    expect(find.text('取消屏蔽'), findsOneWidget);
    expect(find.text('已取消屏蔽'), findsOneWidget);
  });

  testWidgets('clear all restores every forum', (tester) async {
    await tester.pumpWidget(
      _wrap(hidden: {'2', '17'}, names: {'2': '游戏区', '17': '影视区'}),
    );
    await tester.pump();

    await tester.tap(find.byTooltip('全部恢复'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '全部恢复'));
    await tester.pumpAndSettle();

    expect(find.text('暂无屏蔽的版块'), findsOneWidget);
    expect(find.text('取消屏蔽'), findsNothing);
  });
}
