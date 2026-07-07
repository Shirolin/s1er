import 'package:flutter_riverpod/flutter_riverpod.dart';

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
