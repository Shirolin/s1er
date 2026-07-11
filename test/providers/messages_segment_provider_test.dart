import 'package:flutter_test/flutter_test.dart';
import 'package:s1_app/providers/messages_segment_provider.dart';

void main() {
  test('messagesBrowserUrl returns pm page for segment 0', () {
    final url = messagesBrowserUrl(0);
    expect(url, contains('do=pm'));
    expect(url, contains('filter=privatepm'));
  });

  test('messagesBrowserUrl returns notice page for segment 1', () {
    final url = messagesBrowserUrl(1);
    expect(url, contains('do=notice'));
    expect(url, contains('view=all'));
    expect(url, contains('isread=1'));
  });
}
