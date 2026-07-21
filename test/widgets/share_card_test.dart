import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:s1er/config/constants.dart';
import 'package:s1er/models/poll.dart';
import 'package:s1er/models/post.dart';
import 'package:s1er/widgets/share_card.dart';

import '../helpers/test_theme.dart';

/// Provides Riverpod scope and M3 theme for ShareCard tests.
Widget wrap(Widget child) {
  return ProviderScope(
    child: wrapWithAppTheme(
      MediaQuery(
        data: const MediaQueryData(size: Size(800, 600)),
        child: child,
      ),
    ),
  );
}

void main() {
  testWidgets('renders author, floor, and branding', (tester) async {
    final post = Post.fromJson({
      'pid': '123',
      'message': '这是一条测试帖子内容。',
      'author': 'TestUser',
      'authorid': '42',
      'dbdateline': '1720000000',
      'number': '1',
    });

    await tester.pumpWidget(wrap(ShareCard(post: post)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Author name
    expect(find.text('TestUser'), findsOneWidget);
    // Floor pinned to trailing edge of author row
    expect(find.text('#1'), findsOneWidget);
    // Forum branding (top bar); time sits under the author name
    expect(find.text('Stage1st'), findsOneWidget);
    // Client attribution in footer
    expect(find.text('来自 ${S1Constants.appName} 客户端'), findsOneWidget);
    // Post content
    expect(find.textContaining('测试帖子内容'), findsOneWidget);
  });

  testWidgets('renders with displayFloor override', (tester) async {
    final post = Post.fromJson({
      'pid': '456',
      'message': 'Hello',
      'author': 'Author',
      'authorid': '7',
      'dbdateline': '1720000000',
      'number': '3',
    });

    await tester.pumpWidget(wrap(ShareCard(post: post, displayFloor: 42)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Floor should show 42 (not 3) - in the author row
    expect(find.text('#42'), findsOneWidget);
    // The original floor #3 should NOT appear
    expect(find.text('#3'), findsNothing);
  });

  testWidgets('handles empty message gracefully', (tester) async {
    final post = Post.fromJson({
      'pid': '789',
      'message': '',
      'author': 'NoPoster',
      'authorid': '99',
      'dbdateline': '1720000000',
      'number': '5',
    });

    await tester.pumpWidget(wrap(ShareCard(post: post)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('NoPoster'), findsOneWidget);
  });

  testWidgets('renders poll when poll is provided', (tester) async {
    final post = Post.fromJson({
      'pid': '101',
      'message': '带投票的主楼正文',
      'author': 'PollUser',
      'authorid': '10',
      'dbdateline': '1720000000',
      'number': '1',
    });

    final poll = ThreadPoll.fromJson({
      'polloptions': {
        '1': {
          'polloptionid': '1',
          'polloption': '选项A',
          'votes': '10',
          'percent': '60.0',
        },
        '2': {
          'polloptionid': '2',
          'polloption': '选项B',
          'votes': '5',
          'percent': '30.0',
        },
      },
      'expirations': '0',
      'multiple': '0',
      'maxchoices': '1',
      'voterscount': '15',
      'visiblepoll': '1',
      'allowvote': '1',
      'remaintime': ['1', '2', '3', '4'],
    });

    await tester.pumpWidget(wrap(ShareCard(post: post, poll: poll)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('投票'), findsOneWidget);
    expect(find.text('单选'), findsOneWidget);
    expect(find.text('选项A'), findsOneWidget);
    expect(find.text('选项B'), findsOneWidget);
    expect(find.textContaining('共 15 人参与'), findsOneWidget);
  });
}
