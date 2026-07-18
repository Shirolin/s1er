import 'package:flutter_test/flutter_test.dart';
import 'package:s1er/utils/discuz_message.dart';

void main() {
  group('formatDiscuzMessage', () {
    test('adds full stop when text has fullwidth comma', () {
      expect(
        formatDiscuzMessage('登录失败，您还可以尝试 4 次'),
        '登录失败，您还可以尝试 4 次。',
      );
    });

    test('does not double full stop', () {
      expect(
        formatDiscuzMessage('登录失败，您还可以尝试 4 次。'),
        '登录失败，您还可以尝试 4 次。',
      );
    });

    test('leaves single-clause fragments alone', () {
      expect(formatDiscuzMessage('密码错误次数过多'), '密码错误次数过多');
    });
  });

  group('friendlyLoginError', () {
    test('maps mobile:login_invalid key', () {
      expect(
        friendlyLoginError(messageval: 'mobile:login_invalid'),
        '登录失败，用户名、密码或安全提问不正确。',
      );
    });

    test('maps login_question_invalid', () {
      expect(
        friendlyLoginError(messageval: 'login_question_invalid'),
        '抱歉，安全提问答案填写错误。',
      );
    });

    test('keeps Discuz Chinese messagestr and formats period', () {
      expect(
        friendlyLoginError(
          messageval: 'login_invalid',
          messagestr: '登录失败，您还可以尝试 4 次',
        ),
        '登录失败，您还可以尝试 4 次。',
      );
    });

    test('falls back when messagestr still has placeholders', () {
      expect(
        friendlyLoginError(
          messageval: 'login_invalid',
          messagestr: '登录失败，您还可以尝试 {loginperm} 次',
        ),
        '登录失败，用户名、密码或安全提问不正确。',
      );
    });

    test('treats messagestr that is itself a key', () {
      expect(
        friendlyLoginError(
          messageval: null,
          messagestr: 'mobile:login_strike',
        ),
        '密码错误次数过多，请 15 分钟后重新登录。',
      );
    });
  });
}
