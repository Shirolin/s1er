import 'package:flutter/foundation.dart';
import 'http_client.dart';
import 'html_parser_service.dart';

class FormhashService extends ChangeNotifier {
  final S1HttpClient? _httpClient;
  final Map<String, _FormhashCacheEntry> _cache = {};

  FormhashService({S1HttpClient? httpClient}) : _httpClient = httpClient;

  String? getFormhash(String tid) {
    final entry = _cache[tid];
    if (entry == null) return null;
    if (DateTime.now().isAfter(entry.expiry)) {
      _cache.remove(tid);
      return null;
    }
    return entry.formhash;
  }

  void cacheFormhash(String tid, String formhash,
      {Duration ttl = const Duration(minutes: 5)}) {
    _cache[tid] = _FormhashCacheEntry(
      formhash: formhash,
      expiry: DateTime.now().add(ttl),
    );
  }

  Future<String> fetchFormhash(String tid) async {
    final cached = getFormhash(tid);
    if (cached != null) return cached;

    if (_httpClient == null) return '';

    final parser = HtmlParserService(_httpClient!);
    final formhash = await parser.getFormhash(tid);

    if (formhash.isNotEmpty) {
      cacheFormhash(tid, formhash);
    }

    return formhash;
  }

  void invalidate(String tid) {
    _cache.remove(tid);
  }
}

class _FormhashCacheEntry {
  final String formhash;
  final DateTime expiry;

  _FormhashCacheEntry({required this.formhash, required this.expiry});
}
