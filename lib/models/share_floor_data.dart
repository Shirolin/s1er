import 'post.dart';

/// One floor in a share-card export (single or multi-floor).
class ShareFloorData {
  const ShareFloorData({
    required this.post,
    required this.displayFloor,
  });

  final Post post;

  /// Absolute floor label shown on the card (`#n`), snapshotted at selection.
  final int displayFloor;
}
