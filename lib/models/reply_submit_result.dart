/// 回复提交结果（成功 / 明确失败 / 状态不确定）。
enum ReplyDisposition { success, rejected, uncertain }

class ReplySubmitResult {
  const ReplySubmitResult({this.pid, this.tid})
      : disposition = ReplyDisposition.success,
        message = null;

  const ReplySubmitResult.rejected(
    this.message, {
    this.pid,
    this.tid,
  }) : disposition = ReplyDisposition.rejected;

  const ReplySubmitResult.uncertain(
    this.message, {
    this.pid,
    this.tid,
  }) : disposition = ReplyDisposition.uncertain;

  /// 兼容旧构造：`error` 非空视为明确失败。
  factory ReplySubmitResult.withError({
    String? error,
    String? pid,
    String? tid,
  }) {
    if (error != null && error.isNotEmpty) {
      return ReplySubmitResult.rejected(error, pid: pid, tid: tid);
    }
    return ReplySubmitResult(pid: pid, tid: tid);
  }

  final ReplyDisposition disposition;
  final String? message;
  final String? pid;
  final String? tid;

  /// 兼容旧字段：仅 [ReplyDisposition.rejected] 时有值。
  String? get error =>
      disposition == ReplyDisposition.rejected ? message : null;

  bool get isSuccess => disposition == ReplyDisposition.success;
  bool get isUncertain => disposition == ReplyDisposition.uncertain;
}
