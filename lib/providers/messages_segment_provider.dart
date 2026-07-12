import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/api_config.dart';

/// 消息页当前分段：0 = 我的消息，1 = 我的提醒。
class MessagesSegment extends Notifier<int> {
  @override
  int build() => 0;

  void select(int index) => state = index;
}

final messagesSegmentProvider =
    NotifierProvider<MessagesSegment, int>(MessagesSegment.new);

String messagesBrowserUrl(int segment) {
  if (segment == 1) {
    return '${ApiConfig.baseUrl}/home.php'
        '?mod=space&do=notice&view=all&type=&isread=1';
  }
  return '${ApiConfig.baseUrl}/home.php?mod=space&do=pm&filter=privatepm';
}
