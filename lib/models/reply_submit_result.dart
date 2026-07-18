/// 回复提交结果（成功时 [error] 为 null，并尽量带回新帖 pid/tid）。
class ReplySubmitResult {
  const ReplySubmitResult({this.error, this.pid, this.tid});

  final String? error;
  final String? pid;
  final String? tid;

  bool get isSuccess => error == null;
}
