import 'package:flutter_test/flutter_test.dart';
import 'package:s1er/models/post.dart';
import 'package:s1er/models/share_floor_data.dart';
import 'package:s1er/models/share_image_format.dart';
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

  group('PostShareService.fileNameFor', () {
    ShareFloorData floor(String pid) => ShareFloorData(
          post: Post.fromJson({
            'pid': pid,
            'message': 'm',
            'author': 'a',
            'authorid': '1',
            'dbdateline': '1',
            'number': '1',
          }),
          displayFloor: 1,
        );

    test('single floor keeps pid filename', () {
      expect(
        PostShareService.fileNameFor(
          floors: [floor('42')],
          format: ShareImageFormat.webp,
        ),
        's1_42.webp',
      );
    });

    test('multi floor uses tid and count', () {
      expect(
        PostShareService.fileNameFor(
          floors: [floor('1'), floor('2')],
          format: ShareImageFormat.jpeg,
          tid: '999',
        ),
        's1_999_1_x2.jpg',
      );
    });
  });
}
