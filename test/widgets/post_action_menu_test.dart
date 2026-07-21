import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:s1er/theme/app_theme.dart';
import 'package:s1er/widgets/post_action_menu.dart';
import 'package:s1er/widgets/s1_menu.dart';

void main() {
  testWidgets('PostActionMenu opens below trigger with all S1 actions',
      (tester) async {
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
    expect(find.text('编辑'), findsOneWidget);
    expect(find.text('评分'), findsOneWidget);
    expect(find.text('分享'), findsOneWidget);
    expect(find.text('选择文字'), findsOneWidget);
    expect(find.text('复制全文'), findsOneWidget);
    expect(find.text('加入黑名单'), findsOneWidget);
    expect(find.text('举报'), findsOneWidget);
    expect(find.byType(S1MenuDivider), findsOneWidget);
    expect(find.byType(MenuItemButton), findsNWidgets(9));

    await tester.tap(find.text('只看该作者'));
    await tester.pumpAndSettle();

    expect(filterTapped, isTrue);
    expect(find.text('只看该作者'), findsNothing);
  });

  testWidgets('PostActionMenu shows enabled blacklist when callback provided',
      (tester) async {
    var blacklistTapped = false;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme('purple'),
        home: Scaffold(
          body: PostActionMenu(
            onFilterByAuthor: () {},
            onAddToBlacklist: () => blacklistTapped = true,
          ),
        ),
      ),
    );

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();

    await tester.tap(find.text('加入黑名单'));
    await tester.pumpAndSettle();

    expect(blacklistTapped, isTrue);
  });

  testWidgets('PostActionMenu shows enabled reply when callback provided',
      (tester) async {
    var replyTapped = false;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme('purple'),
        home: Scaffold(
          body: PostActionMenu(
            onFilterByAuthor: () {},
            onReply: () => replyTapped = true,
          ),
        ),
      ),
    );

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();

    await tester.tap(find.text('回复'));
    await tester.pumpAndSettle();

    expect(replyTapped, isTrue);
  });

  testWidgets('PostActionMenu shows enabled rate when callback provided',
      (tester) async {
    var rateTapped = false;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme('purple'),
        home: Scaffold(
          body: PostActionMenu(
            onFilterByAuthor: () {},
            onRate: () => rateTapped = true,
          ),
        ),
      ),
    );

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();

    await tester.tap(find.text('评分'));
    await tester.pumpAndSettle();

    expect(rateTapped, isTrue);
  });

  testWidgets('PostActionMenu invokes report callback', (tester) async {
    var reportTapped = false;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme('purple'),
        home: Scaffold(
          body: PostActionMenu(onReport: () => reportTapped = true),
        ),
      ),
    );

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('举报'));
    await tester.pumpAndSettle();

    expect(reportTapped, isTrue);
  });

  testWidgets('PostActionMenu invokes select text callback', (tester) async {
    var selectTapped = false;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme('purple'),
        home: Scaffold(
          body: PostActionMenu(
            onSelectText: () => selectTapped = true,
          ),
        ),
      ),
    );

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('选择文字'));
    await tester.pumpAndSettle();

    expect(selectTapped, isTrue);
  });

  testWidgets('PostActionMenu invokes copy text callback', (tester) async {
    var copyTapped = false;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme('purple'),
        home: Scaffold(
          body: PostActionMenu(
            onCopyText: () => copyTapped = true,
          ),
        ),
      ),
    );

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('复制全文'));
    await tester.pumpAndSettle();

    expect(copyTapped, isTrue);
  });

  testWidgets('PostActionMenu shows disabled labels for unimplemented actions',
      (tester) async {
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
    expect(find.text('复制全文'), findsOneWidget);
    expect(find.text('举报'), findsOneWidget);
  });
}
