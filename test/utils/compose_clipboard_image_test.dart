import 'package:flutter_test/flutter_test.dart';
import 'package:s1er/utils/compose_clipboard_image.dart';

void main() {
  test('composeClipboardImageFilename uses paste_ prefix and png', () {
    final name = composeClipboardImageFilename(DateTime(2026, 7, 22, 18, 30, 5));
    expect(name, 'paste_20260722_183005.png');
  });
}
