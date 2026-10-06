/// `S1HttpClient` 从响应/错误体中观测到的、需要向上层通知的事件。
///
/// 客户端只观测与转发，不直接读写 provider；由 provider 层的适配器
/// （`http_event_bridge_provider`）订阅 [S1HttpClient.events] 后分发到
/// 各自的 notifier。见 [ADR-0004]。
sealed class S1HttpEvent {
  const S1HttpEvent();
}

/// 响应 `Variables.notice` 中的未读计数（私信 / 提醒 / 回帖）。
class S1UnreadNoticeEvent extends S1HttpEvent {
  const S1UnreadNoticeEvent(this.noticeMap);
  final Map<String, dynamic> noticeMap;
}

/// 服务器官方公告原文（会话级提示，只搬运不拟制）。
class S1ServerNoticeEvent extends S1HttpEvent {
  const S1ServerNoticeEvent(this.message);
  final String message;
}
