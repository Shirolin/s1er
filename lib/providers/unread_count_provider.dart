import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/unread_count.dart';

class UnreadCountNotifier extends Notifier<UnreadCount> {
  @override
  UnreadCount build() => UnreadCount.zero;

  void updateFromNotice(Map<String, dynamic> noticeMap) {
    final newCount = UnreadCount.fromJson(noticeMap);
    if (state != newCount) {
      state = newCount;
    }
  }

  void clear() {
    if (state != UnreadCount.zero) {
      state = UnreadCount.zero;
    }
  }

  void debugSetState(UnreadCount count) {
    state = count;
  }
}

final unreadCountProvider = NotifierProvider<UnreadCountNotifier, UnreadCount>(
  UnreadCountNotifier.new,
);
