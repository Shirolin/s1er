import 'package:flutter_test/flutter_test.dart';
import 'package:s1_app/services/auth_service.dart';
import 'package:s1_app/services/formhash_service.dart';

void main() {
  group('AuthService', () {
    test('initial state is logged out', () {
      final auth = AuthService();
      expect(auth.isLoggedIn, false);
      expect(auth.currentUser, null);
    });

    test('logout clears state', () {
      final auth = AuthService();
      auth.logout();
      expect(auth.isLoggedIn, false);
      expect(auth.currentUser, null);
    });
  });

  group('FormhashService', () {
    test('singleton updates and clears formhash', () {
      final service = FormhashService();
      expect(service.formhash, '');

      service.updateFormhash('abc123');
      expect(service.formhash, 'abc123');

      service.clear();
      expect(service.formhash, '');
    });
  });
}
