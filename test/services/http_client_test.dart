import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:s1_app/utils/cookie_store.dart';

void main() {
  late Directory tempDir;

  setUpAll(() async {
    tempDir = Directory.systemTemp.createTempSync('hive_test');
    Hive.init(tempDir.path);
  });

  tearDownAll(() async {
    await Hive.close();
    tempDir.deleteSync(recursive: true);
  });

  setUp(() async {
    if (Hive.isBoxOpen('cookies')) {
      await Hive.box('cookies').clear();
    } else {
      await Hive.openBox('cookies');
    }
  });

  CookieStore createStore() {
    final store = CookieStore();
    store.initSync();
    return store;
  }

  group('CookieStore', () {
    test('saves and retrieves cookies', () async {
      final store = createStore();

      store.setCookies({'sessionid': 'abc123', 'user': 'test'});
      final cookies = store.getCookies();

      expect(cookies['sessionid'], 'abc123');
      expect(cookies['user'], 'test');
    });

    test('clears cookies', () async {
      final store = createStore();

      store.setCookies({'sessionid': 'abc123'});
      await store.clear();
      expect(store.getCookies(), isEmpty);
    });

    test('formats cookies for HTTP header', () async {
      final store = createStore();

      store.setCookies({'a': '1', 'b': '2'});
      final header = store.toHeaderString();

      expect(header, contains('a=1'));
      expect(header, contains('b=2'));
      expect(header, contains('; '));
    });

    test('isEmpty reflects box state', () async {
      final store = createStore();

      expect(store.isEmpty, isTrue);

      store.setCookies({'key': 'value'});
      expect(store.isEmpty, isFalse);

      await store.clear();
      expect(store.isEmpty, isTrue);
    });

    test('overwrites existing cookie values', () async {
      final store = createStore();

      store.setCookies({'sid': 'old_value'});
      store.setCookies({'sid': 'new_value'});

      final cookies = store.getCookies();
      expect(cookies['sid'], 'new_value');
    });

    test('returns empty map when no cookies set', () async {
      final store = createStore();

      final cookies = store.getCookies();
      expect(cookies, isEmpty);
    });

    test('toHeaderString returns empty string when no cookies', () async {
      final store = createStore();

      expect(store.toHeaderString(), isEmpty);
    });
  });
}
