import 'package:flutter_test/flutter_test.dart';
import 'package:s1er/models/user.dart';
import 'package:s1er/providers/auth_provider.dart';
import 'package:s1er/providers/settings_provider.dart';
import 'package:s1er/screens/thread_detail_screen.dart';

void main() {
  test('recordReadingHistory=false blocks reading progress writes', () {
    const settings = AppSettings(recordReadingHistory: false);
    final auth = AuthState(isLoggedIn: false);

    expect(shouldRecordReadingProgress(settings, auth), isFalse);
  });

  test('logged in state with missing uid blocks reading progress writes', () {
    const settings = AppSettings(recordReadingHistory: true);
    final auth = AuthState(
      isLoggedIn: true,
      user: User(uid: '', username: 'tester'),
    );

    expect(shouldRecordReadingProgress(settings, auth), isFalse);
  });

  test('enabled setting with guest or resolved uid allows reading progress',
      () {
    const settings = AppSettings(recordReadingHistory: true);

    expect(
      shouldRecordReadingProgress(settings, AuthState(isLoggedIn: false)),
      isTrue,
    );
    expect(
      shouldRecordReadingProgress(
        settings,
        AuthState(
          isLoggedIn: true,
          user: User(uid: '100', username: 'tester'),
        ),
      ),
      isTrue,
    );
  });
}
