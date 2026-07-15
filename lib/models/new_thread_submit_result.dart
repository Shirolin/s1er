/// 新主题提交结果。
class NewThreadSubmitResult {
  const NewThreadSubmitResult({this.error, this.pid, this.tid});

  final String? error;
  final String? pid;
  final String? tid;

  bool get isSuccess => error == null && tid != null && tid!.isNotEmpty;
}
