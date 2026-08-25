import 'package:flutter_test/flutter_test.dart';
import 'package:s1er/utils/terminal_refresh_arming.dart';

void main() {
  test('same-gesture bounce does not refresh; second gesture does', () {
    final arming = TerminalRefreshArming();

    expect(arming.shouldRefresh(repeating: false), isFalse);
    expect(arming.shouldRefresh(repeating: true), isFalse);

    arming.onScrollEnd();
    expect(arming.shouldRefresh(repeating: true), isTrue);
    expect(arming.shouldRefresh(repeating: true), isFalse);
  });

  test('first hit after timeout requires another release', () {
    final arming = TerminalRefreshArming();
    expect(arming.shouldRefresh(repeating: false), isFalse);
    arming.onScrollEnd();

    expect(arming.shouldRefresh(repeating: false), isFalse);
    expect(arming.shouldRefresh(repeating: true), isFalse);

    arming.onScrollEnd();
    expect(arming.shouldRefresh(repeating: true), isTrue);
  });

  test('reset clears armed state', () {
    final arming = TerminalRefreshArming();
    arming.shouldRefresh(repeating: false);
    arming.onScrollEnd();
    arming.reset();
    expect(arming.shouldRefresh(repeating: true), isFalse);
  });
}
