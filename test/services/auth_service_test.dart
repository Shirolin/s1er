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

    test('restoreSession sets logged in with cookies', () {
      final auth = AuthService();
      auth.restoreSession({'sessionid': 'abc123'});
      expect(auth.isLoggedIn, true);
    });

    test('restoreSession does nothing with empty cookies', () {
      final auth = AuthService();
      auth.restoreSession({});
      expect(auth.isLoggedIn, false);
    });
  });

  group('FormhashService', () {
    test('caches formhash per thread', () {
      final service = FormhashService();
      service.cacheFormhash('123', 'abc123');
      expect(service.getFormhash('123'), 'abc123');
    });

    test('returns null for expired cache', () {
      final service = FormhashService();
      service.cacheFormhash('123', 'abc123', ttl: const Duration(seconds: -1));
      expect(service.getFormhash('123'), null);
    });

    test('returns null for uncached thread', () {
      final service = FormhashService();
      expect(service.getFormhash('999'), null);
    });

    test('invalidate removes cached entry', () {
      final service = FormhashService();
      service.cacheFormhash('123', 'abc123');
      expect(service.getFormhash('123'), 'abc123');
      service.invalidate('123');
      expect(service.getFormhash('123'), null);
    });

    test('different threads have separate caches', () {
      final service = FormhashService();
      service.cacheFormhash('111', 'aaa');
      service.cacheFormhash('222', 'bbb');
      expect(service.getFormhash('111'), 'aaa');
      expect(service.getFormhash('222'), 'bbb');
    });
  });
}
