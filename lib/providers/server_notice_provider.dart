import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 论坛服务器官方公告（会话级）。
///
/// 由 provider 层的 HTTP 事件桥（`httpEventBridgeProvider`）从
/// `S1HttpClient.events` 的 `S1ServerNoticeEvent` 分发；只搬运、不拟制。
/// 同一文案会话内只提示一次（关闭后不复现），服务器下发新文案时更新。
class ServerNoticeNotifier extends Notifier<String?> {
  String? _lastOffered;

  @override
  String? build() => null;

  /// 喂入一条官方原文（空串与 `to_login` 已在提取层过滤）。
  void offer(String message) {
    final trimmed = message.trim();
    if (trimmed.isEmpty || trimmed == _lastOffered) return;
    _lastOffered = trimmed;
    state = trimmed;
  }

  /// 用户关闭当前提示；同一文案本会话内不再提示。
  void dismiss() {
    state = null;
  }
}

final serverNoticeProvider =
    NotifierProvider<ServerNoticeNotifier, String?>(ServerNoticeNotifier.new);
