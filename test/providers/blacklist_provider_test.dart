import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:s1_app/models/blacklist_record.dart';
import 'package:s1_app/providers/blacklist_provider.dart';
import 'package:s1_app/providers/settings_provider.dart';
import 'package:s1_app/services/app_database.dart';
import 'package:s1_app/services/app_local_data.dart';

void main() {
  late AppDatabase db;
  late AppLocalData local;
  late ProviderContainer container;

  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    db = AppDatabase.forTesting(NativeDatabase.memory());
    local = AppLocalData(db);
    await local.load();
    container = ProviderContainer(
      overrides: [
        localDataProvider.overrideWithValue(local),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await local.flushPendingWrites();
    await db.close();
  });

  test('upsert add/remove and hasScope', () async {
    await container.read(blacklistBootstrapProvider.future);
    final notifier = container.read(blacklistProvider.notifier);

    notifier.upsert(
      uid: '9',
      username: 'eve',
      scope: [BlacklistRecord.scopeThread, BlacklistRecord.scopePost],
    );

    expect(container.read(blacklistProvider), hasLength(1));
    expect(notifier.isBlocked('9'), isTrue);
    expect(notifier.hasScope('9', BlacklistRecord.scopeThread), isTrue);
    expect(
      container.read(
        blacklistHasScopeProvider(
          (
            uid: '9',
            scope: BlacklistRecord.scopePost,
          ),
        ),
      ),
      isTrue,
    );
    expect(
      container.read(
        blacklistHasScopeProvider(
          (
            uid: '9',
            scope: BlacklistRecord.scopePm,
          ),
        ),
      ),
      isFalse,
    );

    notifier.remove('9');
    expect(container.read(blacklistProvider), isEmpty);
    expect(notifier.isBlocked('9'), isFalse);
  });
}
