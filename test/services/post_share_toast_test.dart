import 'package:flutter_test/flutter_test.dart';
import 'package:s1er/services/post_share_service.dart';
import 'package:share_plus/share_plus.dart';

void main() {
  group('PostShareService.toastMessageForShareResult', () {
    test('success reports share completed', () {
      expect(
        PostShareService.toastMessageForShareResult(ShareResultStatus.success),
        '分享成功',
      );
    });

    test('unavailable confirms share UI handoff', () {
      expect(
        PostShareService.toastMessageForShareResult(
          ShareResultStatus.unavailable,
        ),
        '已打开分享',
      );
    });

    test('dismissed stays quiet', () {
      expect(
        PostShareService.toastMessageForShareResult(
          ShareResultStatus.dismissed,
        ),
        isNull,
      );
    });
  });
}
