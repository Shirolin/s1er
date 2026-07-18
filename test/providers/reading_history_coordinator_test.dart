import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:s1er/models/user.dart';
import 'package:s1er/providers/auth_provider.dart';
import 'package:s1er/providers/reading_history_coordinator.dart';
import 'package:s1er/providers/reading_history_provider.dart';
import 'package:s1er/providers/settings_provider.dart';
import 'package:s1er/services/app_database.dart';
import 'package:s1er/services/app_local_data.dart';
import 'package:s1er/services/reading_history_service.dart';

class _TestAuthNotifier extends AuthNotifier {
  void setUser(User? user) {
    if (user == null) {
      state = AuthState();
      return;
    }
    state = AuthState(
      isLoggedIn: true,
      username: user.username,
      user: user,
    );
  }
}

void _recordGuest(AppLocalData local, String tid) {
  ReadingHistoryService(local, 'guest').updateProgress(
    tid: tid,
    page: 2,
    floorInPage: 5,
    subject: 'guest subject',
    author: 'a',
    fid: '4',
    totalPages: 3,
    totalReplies: 80,
    perPage: 40,
    isNewVisit: true,
  );
}

void main() {
  late AppDatabase db;
  late AppLocalData local;
  late ProviderContainer container;
  late _TestAuthNotifier authNotifier;

  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    db = AppDatabase.forTesting(NativeDatabase.memory());
    local = AppLocalData(db);
    await local.load();
    container = ProviderContainer(
      overrides: [
        localDataProvider.overrideWithValue(local),
        authStateProvider.overrideWith(() {
          authNotifier = _TestAuthNotifier();
          return authNotifier;
        }),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  test('guest login migrates reading history to user namespace', () async {
    _recordGuest(local, '42');
    expect(ReadingHistoryService(local, 'guest').getRecord('42'), isNotNull);

    container.read(readingHistoryCoordinatorProvider);
    authNotifier.setUser(User(uid: '10001', username: 'alice'));
    await Future<void>.delayed(Duration.zero);

    expect(ReadingHistoryService(local, 'guest').getRecord('42'), isNull);
    expect(ReadingHistoryService(local, '10001').getRecord('42'), isNotNull);

    final list = container.read(readingHistoryProvider).records;
    expect(list.map((r) => r.tid), ['42']);
    expect(list.single.lastReadPage, 2);
  });

  test('cold start logged in migrates orphan guest records', () async {
    _recordGuest(local, '99');

    container.read(readingHistoryCoordinatorProvider);
    authNotifier.setUser(User(uid: '20002', username: 'bob'));
    await Future<void>.delayed(Duration.zero);

    expect(ReadingHistoryService(local, '20002').getRecord('99'), isNotNull);
    expect(local.readingHistory.containsKey('guest_99'), isFalse);
  });

  test('logout switches history list to guest namespace', () async {
    ReadingHistoryService(local, '10001').updateProgress(
      tid: '1',
      page: 1,
      floorInPage: 1,
      subject: 'user subject',
      author: 'a',
      fid: '4',
      totalPages: 1,
      totalReplies: 0,
      perPage: 40,
      isNewVisit: true,
    );

    container.read(readingHistoryCoordinatorProvider);
    authNotifier.setUser(User(uid: '10001', username: 'alice'));
    await Future<void>.delayed(Duration.zero);
    expect(container.read(readingHistoryProvider).isNotEmpty, isTrue);

    authNotifier.setUser(null);
    await Future<void>.delayed(Duration.zero);

    expect(container.read(readingHistoryProvider).isEmpty, isTrue);
  });

  test('uid change without guest keys does not throw', () {
    container.read(readingHistoryCoordinatorProvider);
    authNotifier.setUser(User(uid: '30003', username: 'carol'));
    authNotifier.setUser(null);

    expect(container.read(currentReadingUidProvider), 'guest');
  });
}
