// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter

import 'dart:html' show window;

void persistInitError(String error) {
  window.localStorage['s1_init_error'] = error;
  window.localStorage['s1_init_time'] = DateTime.now().toIso8601String();
}

String? readPersistedInitError() {
  final error = window.localStorage['s1_init_error'];
  if (error == null || error.isEmpty) return null;
  final time = window.localStorage['s1_init_time'];
  clearPersistedInitError();
  final when = time != null ? ' [$time]' : '';
  return 'Crash$when:\n$error';
}

void clearPersistedInitError() {
  window.localStorage.remove('s1_init_error');
  window.localStorage.remove('s1_init_time');
}
