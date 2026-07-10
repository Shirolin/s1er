import 'package:flutter_test/flutter_test.dart';
import 'package:s1_app/theme/app_theme.dart';

void main() {
  test('AppBar uses zero scrolledUnderElevation', () {
    final theme = AppTheme.lightTheme('purple');
    expect(theme.appBarTheme.elevation, 0);
    expect(theme.appBarTheme.scrolledUnderElevation, 0);
  });
}
