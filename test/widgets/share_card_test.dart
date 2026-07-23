import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:s1er/config/constants.dart';
import 'package:s1er/models/poll.dart';
import 'package:s1er/models/post.dart';
import 'package:s1er/models/share_floor_data.dart';
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

Post _post({
  required String pid,
  required String message,
  required String author,
  required String number,
}) {
  return Post.fromJson({
    'pid': pid,
    'message': message,
    'author': author,
    'authorid': '42',
    'dbdateline': '1720000000',
    'number': number,
  });
}

void main() {
  testWidgets('renders author, floor, and branding', (tester) async {
    final post = _post(
      pid: '123',
      message: '这是一条测试帖子内容。',
      author: 'TestUser',
      number: '1',
    );

    await tester.pumpWidget(wrap(ShareCard.single(post: post)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('TestUser'), findsOneWidget);
    expect(find.text('#1'), findsOneWidget);
    expect(find.text('Stage1st'), findsOneWidget);
    expect(find.text('来自 ${S1Constants.appName} 客户端'), findsOneWidget);
    expect(find.textContaining('测试帖子内容'), findsOneWidget);
  });

  testWidgets('renders with displayFloor override', (tester) async {
    final post = _post(
      pid: '456',
      message: 'Hello',
      author: 'Author',
      number: '3',
    );

    await tester.pumpWidget(
      wrap(ShareCard.single(post: post, displayFloor: 42)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('#42'), findsOneWidget);
    expect(find.text('#3'), findsNothing);
  });

  testWidgets('handles empty message gracefully', (tester) async {
    final post = _post(
      pid: '789',
      message: '',
      author: 'NoPoster',
      number: '5',
    );

    await tester.pumpWidget(wrap(ShareCard.single(post: post)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('NoPoster'), findsOneWidget);
  });

  testWidgets('renders poll when poll is provided', (tester) async {
    final post = _post(
      pid: '101',
      message: '带投票的主楼正文',
      author: 'PollUser',
      number: '1',
    );

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

    await tester.pumpWidget(wrap(ShareCard.single(post: post, poll: poll)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('投票'), findsOneWidget);
    expect(find.text('单选'), findsOneWidget);
    expect(find.text('选项A'), findsOneWidget);
    expect(find.text('选项B'), findsOneWidget);
    expect(find.textContaining('共 15 人参与'), findsOneWidget);
  });

  testWidgets('multi-floor card shows one title and both floors',
      (tester) async {
    final floors = [
      ShareFloorData(
        post: _post(pid: '1', message: '一楼内容', author: 'Alice', number: '1'),
        displayFloor: 1,
      ),
      ShareFloorData(
        post: _post(pid: '2', message: '二楼内容', author: 'Bob', number: '2'),
        displayFloor: 2,
      ),
    ];

    await tester.pumpWidget(
      wrap(
        SingleChildScrollView(
          child: ShareCard(
            floors: floors,
            threadSubject: '测试主题标题',
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('测试主题标题'), findsOneWidget);
    expect(find.text('Stage1st'), findsOneWidget);
    expect(find.text('来自 ${S1Constants.appName} 客户端'), findsOneWidget);
    expect(find.text('Alice'), findsOneWidget);
    expect(find.text('Bob'), findsOneWidget);
    expect(find.text('#1'), findsOneWidget);
    expect(find.text('#2'), findsOneWidget);
    expect(find.textContaining('一楼内容'), findsOneWidget);
    expect(find.textContaining('二楼内容'), findsOneWidget);
  });

  testWidgets('poll only attaches to floor #1 in multi-floor card',
      (tester) async {
    final floors = [
      ShareFloorData(
        post: _post(pid: '1', message: '主楼', author: 'Alice', number: '1'),
        displayFloor: 1,
      ),
      ShareFloorData(
        post: _post(pid: '2', message: '跟帖', author: 'Bob', number: '2'),
        displayFloor: 2,
      ),
    ];
    final poll = ThreadPoll.fromJson({
      'polloptions': {
        '1': {
          'polloptionid': '1',
          'polloption': '选项A',
          'votes': '10',
          'percent': '100.0',
        },
      },
      'expirations': '0',
      'multiple': '0',
      'maxchoices': '1',
      'voterscount': '10',
      'visiblepoll': '1',
      'allowvote': '1',
      'remaintime': ['0', '0', '0', '0'],
    });

    await tester.pumpWidget(
      wrap(
        SingleChildScrollView(
          child: ShareCard(floors: floors, poll: poll),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('投票'), findsOneWidget);
    expect(find.text('选项A'), findsOneWidget);
  });
}
