import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/api_config.dart';
import '../models/notice_item.dart';

/// 消息页当前分段：0 = 我的提醒，1 = 我的消息。
class MessagesSegment extends Notifier<int> {
  @override
  int build() => 0;

  void select(int index) => state = index;
}

final messagesSegmentProvider =
    NotifierProvider<MessagesSegment, int>(MessagesSegment.new);

class NoticeFeedSelection extends Notifier<NoticeFeed> {
  @override
  NoticeFeed build() => NoticeFeed.mypost;

  void select(NoticeFeed feed) => state = feed;
}

final noticeFeedSelectionProvider =
    NotifierProvider<NoticeFeedSelection, NoticeFeed>(
  NoticeFeedSelection.new,
);

String messagesBrowserUrl(
  int segment, {
  NoticeFeed noticeFeed = NoticeFeed.mypost,
  int page = 1,
}) {
  return ApiConfig.messagesBrowserUrl(
    isNotice: segment == 0,
    noticeFeed: noticeFeed.name,
    page: page,
  );
}
