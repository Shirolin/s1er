import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'talker.dart';

class FormhashNotifier extends Notifier<String> {
  @override
  String build() => '';

  void update(String? value) {
    if (value != null && value.isNotEmpty && value != state) {
      state = value;
    }
  }

  void clear() => state = '';
}

final formhashProvider = NotifierProvider<FormhashNotifier, String>(
  FormhashNotifier.new,
);

/// 从 Mobile API JSON 或 forum.php HTML 中提取 formhash。
class FormhashExtractor {
  FormhashExtractor._();

  static String? fromApiResponse(dynamic data) {
    try {
      final json = _asJsonMap(data);
      if (json == null) return null;
      final variables = json['Variables'];
      if (variables is! Map) return null;
      final formhash = variables['formhash'];
      if (formhash is String && formhash.isNotEmpty) return formhash;
    } catch (e, st) {
      talker.debug('Failed to extract formhash from API response', e, st);
    }
    return null;
  }

  static String? fromHtml(String html) {
    final patterns = [
      RegExp(r'''name=["']formhash["']\s+value=["']([^"']+)["']'''),
      RegExp(r'''name=["']formhash["']\s+value=([^\s>]+)'''),
      RegExp(r'''formhash=([a-f0-9]{8})'''),
    ];
    for (final pattern in patterns) {
      final match = pattern.firstMatch(html);
      final value = match?.group(1)?.trim();
      if (value != null && value.isNotEmpty) return value;
    }
    return null;
  }

  static Map<String, dynamic>? _asJsonMap(dynamic data) {
    if (data is Map<String, dynamic>) return data;
    if (data is String) {
      final trimmed = data.trimLeft();
      if (!trimmed.startsWith('{')) return null;
      return jsonDecode(data) as Map<String, dynamic>;
    }
    return null;
  }
}
