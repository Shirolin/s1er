import 'package:flutter_test/flutter_test.dart';
import 'package:s1_app/models/poll.dart';

void main() {
  group('ThreadPoll', () {
    test('fromJson parses poll options and metadata', () {
      final poll = ThreadPoll.fromJson({
        'polloptions': {
          '1': {
            'polloptionid': '82378',
            'polloption': '选项 A',
            'votes': '80',
            'percent': '12.50',
            'color': 'E92725',
          },
          '2': {
            'polloptionid': '82379',
            'polloption': '选项 B',
            'votes': '533',
            'percent': '83.28',
            'color': '5AAF4A',
          },
        },
        'expirations': '2083678682',
        'multiple': '0',
        'maxchoices': '1',
        'voterscount': '640',
        'visiblepoll': '1',
        'allowvote': '1',
        'remaintime': ['1', '0', '19', '40'],
      });

      expect(poll.options.length, 2);
      expect(poll.options[0].id, '82378');
      expect(poll.options[0].text, '选项 A');
      expect(poll.options[0].votes, 80);
      expect(poll.options[0].percent, 12.5);
      expect(poll.options[1].colorHex, '5AAF4A');
      expect(poll.multiple, isFalse);
      expect(poll.maxChoices, 1);
      expect(poll.votersCount, 640);
      expect(poll.visibleResults, isTrue);
      expect(poll.allowVote, isTrue);
      expect(poll.remainTime, [1, 0, 19, 40]);
      expect(poll.isExpired, isFalse);
      expect(poll.canVote, isTrue);
      expect(poll.showResults, isTrue);
      expect(poll.remainTimeLabel, '剩余 1天19分');
      expect(poll.voteModeLabel, '单选');
    });

    test('isExpired when remaintime is all zero', () {
      final poll = ThreadPoll.fromJson({
        'polloptions': {},
        'remaintime': ['0', '0', '0', '0'],
      });

      expect(poll.isExpired, isTrue);
      expect(poll.canVote, isFalse);
      expect(poll.remainTimeLabel, '投票已结束');
    });

    test('withUserVotes marks matching options', () {
      final poll = ThreadPoll.fromJson({
        'polloptions': {
          '1': {
            'polloptionid': '1',
            'polloption': 'A',
            'votes': '1',
            'percent': '50',
            'color': 'E92725',
          },
          '2': {
            'polloptionid': '2',
            'polloption': 'B',
            'votes': '1',
            'percent': '50',
            'color': '5AAF4A',
          },
        },
        'allowvote': '',
      });

      final marked = poll.withUserVotes(['2']);
      expect(marked.hasUserVoted, isTrue);
      expect(marked.options[0].isUserVote, isFalse);
      expect(marked.options[1].isUserVote, isTrue);
    });
  });
}
