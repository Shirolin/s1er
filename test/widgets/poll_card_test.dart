import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:s1er/models/poll.dart';
import 'package:s1er/models/user.dart';
import 'package:s1er/providers/auth_provider.dart';
import 'package:s1er/widgets/poll_card.dart';

import '../helpers/test_theme.dart';

void main() {
  Widget wrap(Widget child) {
    return ProviderScope(
      child: wrapWithAppTheme(child),
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

  testWidgets('PollCard falls back to primary for low-contrast API color',
      (tester) async {
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

  testWidgets(
      'PollCard item keeps geometry and supports full-row tap semantics',
      (tester) async {
    final poll = ThreadPoll.fromJson({
      'polloptions': {
        '1': {
          'polloptionid': '1',
          'polloption': '整行点击',
          'votes': '0',
          'percent': '0',
          'color': '5AAF4A',
        },
      },
      'multiple': '1',
      'maxchoices': '1',
      'voterscount': '0',
      'visiblepoll': '1',
      'allowvote': '1',
      'remaintime': ['1', '0', '0', '0'],
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateProvider.overrideWith(_LoggedInAuthNotifier.new),
        ],
        child: MaterialApp(
          theme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
          ),
          home: Scaffold(body: PollCard(poll: poll, tid: '1')),
        ),
      ),
    );

    final optionFinder = find.text('整行点击');
    final tileFinder = find.ancestor(
      of: optionFinder,
      matching: find.byType(InkWell),
    );
    final before = tester.getSize(tileFinder);

    final semantics = tester.getSemantics(optionFinder);
    expect(semantics.label, contains('投票选项：整行点击'));
    expect(semantics.flagsCollection.isButton, isTrue);

    final tileRect = tester.getRect(tileFinder);
    await tester.tapAt(tileRect.topLeft + const Offset(6, 6));
    await tester.pump();

    final after = tester.getSize(tileFinder);
    expect(after, before);
    expect(find.byType(Checkbox), findsOneWidget);
  });
}

class _LoggedInAuthNotifier extends AuthNotifier {
  @override
  AuthState build() {
    return AuthState(
      isLoggedIn: true,
      username: 'tester',
      user: User(uid: '1', username: 'tester'),
    );
  }
}
