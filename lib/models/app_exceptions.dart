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
