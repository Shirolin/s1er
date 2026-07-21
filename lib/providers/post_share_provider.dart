import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/poll.dart';
import '../models/post.dart';
import '../services/post_share_service.dart';

/// Provider for sharing a post as a designed card image.
/// Screens invoke [PostShareNotifier.share] instead of calling the service
/// directly, satisfying the Screen -> Provider -> Service architecture rule.
final postShareProvider =
    NotifierProvider<PostShareNotifier, void>(PostShareNotifier.new);

class PostShareNotifier extends Notifier<void> {
  @override
  void build() {}

  /// Shows the share bottom sheet and handles capture/sharing of [post].
  Future<void> share({
    required BuildContext context,
    required Post post,
    int? displayFloor,
    String? threadSubject,
    ThreadPoll? poll,
  }) async {
    await PostShareService.share(
      context: context,
      post: post,
      displayFloor: displayFloor,
      threadSubject: threadSubject,
      poll: poll,
    );
  }
}
