import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/http_client.dart';
import '../services/s1_http_event.dart';
import 'server_notice_provider.dart';
import 'unread_count_provider.dart';

/// 把 [S1HttpClient.events] 分发到各自的 notifier。
///
/// 这是 provider 层的适配器：客户端只观测与转发事件，不直接读写这两个
/// provider。订阅在 provider 首次被读取时建立，随容器销毁自动取消。
/// 见 [ADR-0004]。
final httpEventBridgeProvider = Provider<void>((ref) {
  final client = ref.watch(httpClientProvider);
  final sub = client.events.listen((event) {
    switch (event) {
      case S1UnreadNoticeEvent(:final noticeMap):
        ref.read(unreadCountProvider.notifier).updateFromNotice(noticeMap);
      case S1ServerNoticeEvent(:final message):
        ref.read(serverNoticeProvider.notifier).offer(message);
    }
  });
  ref.onDispose(sub.cancel);
});
