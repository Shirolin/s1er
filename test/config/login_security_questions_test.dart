import 'package:flutter_test/flutter_test.dart';
import 'package:s1_app/config/login_security_questions.dart';

void main() {
  group('LoginSecurityQuestions', () {
    test('discuz ids are contiguous 0..7 matching S1-Next', () {
      expect(LoginSecurityQuestions.all.map((q) => q.id).toList(),
          [0, 1, 2, 3, 4, 5, 6, 7],);
      expect(LoginSecurityQuestions.all.first.label, contains('未设置'));
      expect(LoginSecurityQuestions.byId(2).label, '爷爷的名字');
      expect(LoginSecurityQuestions.byId(99).id, 0);
    });
  });
}
