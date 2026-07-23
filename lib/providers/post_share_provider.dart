import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/poll.dart';
import '../models/post.dart';
import '../models/share_floor_data.dart';
import '../services/post_share_service.dart';
import '../utils/share_floor_selection.dart';

/// Provider for sharing post(s) as a designed card image.
/// Screens invoke [PostShareNotifier] instead of calling the service
/// directly, satisfying the Screen -> Provider -> Service architecture rule.
final postShareProvider =
    NotifierProvider<PostShareNotifier, void>(PostShareNotifier.new);

class PostShareNotifier extends Notifier<void> {
  @override
  void build() {}

  /// Shows the share bottom sheet for one or more floors.
  Future<void> sharePosts({
    required BuildContext context,
    required List<ShareFloorData> floors,
    String? threadSubject,
    ThreadPoll? poll,
    String? tid,
  }) async {
    if (floors.isEmpty) return;
    final sorted = ShareFloorSelection.sortedForExport(floors);
    final includePoll = poll != null && sorted.any((f) => f.displayFloor == 1);
    await PostShareService.share(
      context: context,
      floors: sorted,
      threadSubject: threadSubject,
      poll: includePoll ? poll : null,
      tid: tid,
    );
  }

  /// Single-floor share (menu「分享」).
  Future<void> share({
    required BuildContext context,
    required Post post,
    int? displayFloor,
    String? threadSubject,
    ThreadPoll? poll,
    String? tid,
  }) {
    return sharePosts(
      context: context,
      floors: [
        ShareFloorData(
          post: post,
          displayFloor: displayFloor ?? post.floor,
        ),
      ],
      threadSubject: threadSubject,
      poll: poll,
      tid: tid,
    );
  }
}
