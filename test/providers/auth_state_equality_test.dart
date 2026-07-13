import 'package:flutter_test/flutter_test.dart';
import 'package:s1_app/models/user.dart';
import 'package:s1_app/providers/auth_provider.dart';

void main() {
  group('AuthState equality', () {
    test('equal states compare equal', () {
      final user = User(uid: '1', username: 'alice');
      final a = AuthState(isLoggedIn: true, username: 'alice', user: user);
      final b = AuthState(isLoggedIn: true, username: 'alice', user: user);

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('different users compare unequal', () {
      final a = AuthState(
        isLoggedIn: true,
        username: 'alice',
        user: User(uid: '1', username: 'alice'),
      );
      final b = AuthState(
        isLoggedIn: true,
        username: 'alice',
        user: User(uid: '2', username: 'alice'),
      );

      expect(a, isNot(equals(b)));
    });
  });
}
