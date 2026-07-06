import 'package:flutter/foundation.dart';

class FormhashService extends ChangeNotifier {
  static final FormhashService _instance = FormhashService._internal();
  FormhashService._internal();
  factory FormhashService() => _instance;

  String _formhash = '';

  String get formhash => _formhash;

  void updateFormhash(String? value) {
    if (value != null && value.isNotEmpty && value != _formhash) {
      _formhash = value;
      notifyListeners();
    }
  }

  void clear() {
    _formhash = '';
    notifyListeners();
  }
}
