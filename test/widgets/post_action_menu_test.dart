import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:s1_app/theme/app_theme.dart';
import 'package:s1_app/widgets/post_action_menu.dart';

void main() {
  testWidgets('PostActionMenu opens below trigger with all S1 actions', (tester) async {
    var filterTapped = false;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme('purple'),
        home: Scaffold(
          body: PostActionMenu(
            onFilterByAuthor: () => filterTapped = true,
          ),
        ),
      ),
    );

    expect(find.text('只看该作者'), findsNothing);

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();

    expect(find.text('只看该作者'), findsOneWidget);
    expect(find.text('回复'), findsOneWidget);
    expect(find.text('评分'), findsOneWidget);
    expect(find.text('举报'), findsOneWidget);
    expect(find.byType(PopupMenuDivider), findsOneWidget);

    await tester.tap(find.text('只看该作者'));
    await tester.pumpAndSettle();

    expect(filterTapped, isTrue);
    expect(find.text('只看该作者'), findsNothing);
  });

  testWidgets('PostActionMenu shows disabled labels for unimplemented actions', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme('purple'),
        home: Scaffold(
          body: PostActionMenu(
            onFilterByAuthor: () {},
          ),
        ),
      ),
    );

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();

    expect(find.text('回复'), findsOneWidget);
    expect(find.text('举报'), findsOneWidget);
  });
}
