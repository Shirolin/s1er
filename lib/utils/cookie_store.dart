import 'package:hive/hive.dart';

class CookieStore {
  static const String _boxName = 'cookies';
  late Box _box;

  Future<void> init() async {
    _box = await Hive.openBox(_boxName);
  }

  /// For test use: bind to an already-open box without async.
  void initSync() {
    _box = Hive.box(_boxName);
  }

  void setCookies(Map<String, String> cookies) {
    for (final entry in cookies.entries) {
      _box.put(entry.key, entry.value);
    }
  }

  Map<String, String> getCookies() {
    final cookies = <String, String>{};
    for (final key in _box.keys) {
      cookies[key.toString()] = _box.get(key).toString();
    }
    return cookies;
  }

  String toHeaderString() {
    final cookies = getCookies();
    return cookies.entries.map((e) => '${e.key}=${e.value}').join('; ');
  }

  Future<void> clear() async {
    await _box.clear();
  }

  bool get isEmpty => _box.isEmpty;
}
