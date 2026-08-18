import 'package:flutter_test/flutter_test.dart';
import 'package:s1er/utils/home_root_back.dart';

void main() {
  final now = DateTime(2026, 8, 18, 10);

  test('non-forum tab goes back to forum', () {
    expect(
      resolveHomeRootBack(
        isForumTab: false,
        now: now,
        lastExitArmedAt: now,
        canExitApp: true,
      ),
      HomeRootBackAction.goForum,
    );
    expect(
      resolveHomeRootBack(
        isForumTab: false,
        now: now,
        canExitApp: false,
      ),
      HomeRootBackAction.goForum,
    );
  });

  test('forum tab first back arms exit', () {
    expect(
      resolveHomeRootBack(
        isForumTab: true,
        now: now,
        canExitApp: true,
      ),
      HomeRootBackAction.armExit,
    );
  });

  test('forum tab back within window exits', () {
    expect(
      resolveHomeRootBack(
        isForumTab: true,
        now: now.add(HomeRootBack.window),
        lastExitArmedAt: now,
        canExitApp: true,
      ),
      HomeRootBackAction.exit,
    );
  });

  test('forum tab back after window arms again', () {
    expect(
      resolveHomeRootBack(
        isForumTab: true,
        now: now.add(HomeRootBack.window + const Duration(milliseconds: 1)),
        lastExitArmedAt: now,
        canExitApp: true,
      ),
      HomeRootBackAction.armExit,
    );
  });

  test('forum tab does not exit off Android', () {
    expect(
      resolveHomeRootBack(
        isForumTab: true,
        now: now,
        lastExitArmedAt: now,
        canExitApp: false,
      ),
      HomeRootBackAction.ignore,
    );
  });
}
