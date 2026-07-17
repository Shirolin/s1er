class LoginRequiredException implements Exception {
  @override
  String toString() => 'LoginRequiredException';
}

class ServerMaintenanceException implements Exception {
  ServerMaintenanceException([this.message = '服务器维护中']);

  final String message;

  @override
  String toString() => message;
}

class UpdateCheckException implements Exception {
  const UpdateCheckException(this.message, [this.cause]);

  final String message;
  final Object? cause;

  @override
  String toString() => message;
}
