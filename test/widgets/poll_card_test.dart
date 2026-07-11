import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:s1_app/theme/app_theme.dart';
import 'package:s1_app/models/poll.dart';
import 'package:s1_app/widgets/poll_card.dart';

void main() {
  Widget wrap(Widget child) {
    return ProviderScope(
      child: MaterialApp(
        theme: AppTheme.lightTheme('purple'),
        home: Scaffold(body: child),
      ),
    );
  }

  testWidgets('PollCard shows options and vote metadata', (tester) async {
    final poll = ThreadPoll.fromJson({
      'polloptions': {
        '1': {
          'polloptionid': '1',
          'polloption': '装死到底',
          'votes': '533',
          'percent': '83.28',
          'color': '5AAF4A',
        },
      },
      'multiple': '0',
      'maxchoices': '1',
      'voterscount': '640',
      'visiblepoll': '1',
      'allowvote': '',
      'remaintime': ['1', '0', '19', '40'],
    }).withUserVotes(['1']);

    await tester.pumpWidget(
      wrap(PollCard(poll: poll, tid: '2285124')),
    );

    expect(find.text('投票'), findsOneWidget);
    expect(find.text('装死到底'), findsOneWidget);
    expect(find.text('我的投票'), findsOneWidget);
    expect(find.textContaining('已标注您投过的选项'), findsOneWidget);
  });

  testWidgets('PollCard falls back to primary for low-contrast API color', (tester) async {
    final poll = ThreadPoll.fromJson({
      'polloptions': {
        '1': {
          'polloptionid': '1',
          'polloption': '浅色选项',
          'votes': '1',
          'percent': '100',
          'color': 'F8F8F8',
        },
      },
      'multiple': '0',
      'maxchoices': '1',
      'voterscount': '1',
      'visiblepoll': '1',
      'allowvote': '',
      'remaintime': ['1', '0', '0', '0'],
    });

    await tester.pumpWidget(
      wrap(PollCard(poll: poll, tid: '1')),
    );

    expect(find.text('浅色选项'), findsOneWidget);
  });
}
