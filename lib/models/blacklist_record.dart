/// 本地黑名单条目（纯 Dart；对应 Drift `blacklist_entries`）。
class BlacklistRecord {
  const BlacklistRecord({
    required this.uid,
    this.username = '',
    required this.createdAt,
    this.reason = '',
    this.scope = const [],
  });

  factory BlacklistRecord.fromStorage({
    required String uid,
    required String username,
    required int createdAt,
    required String reason,
    required List<Object?> scopeRaw,
  }) {
    return BlacklistRecord(
      uid: uid,
      username: username,
      createdAt: createdAt,
      reason: reason,
      scope: normalizeScopes(scopeRaw),
    );
  }

  factory BlacklistRecord.fromJson(Map<String, dynamic> json) {
    final scopeRaw = json['scope'];
    return BlacklistRecord.fromStorage(
      uid: json['uid']?.toString() ?? '',
      username: json['username']?.toString() ?? '',
      createdAt: (json['createdAt'] as num?)?.toInt() ?? 0,
      reason: json['reason']?.toString() ?? '',
      scopeRaw: scopeRaw is List ? scopeRaw : const [],
    );
  }

  /// 被拉黑用户 uid（设备级主键）。
  final String uid;
  final String username;

  /// 加入时间（millisecondsSinceEpoch）。
  final int createdAt;
  final String reason;

  /// 作用域：`thread` / `post` / `pm`（未知值应在解析时丢弃）。
  final List<String> scope;

  static const scopeThread = 'thread';
  static const scopePost = 'post';
  static const scopePm = 'pm';

  static const knownScopes = {scopeThread, scopePost, scopePm};

  /// 拉黑时的默认作用域。
  static const defaultScopes = [scopeThread, scopePost];

  bool hasScope(String value) => scope.contains(value);

  BlacklistRecord copyWith({
    String? uid,
    String? username,
    int? createdAt,
    String? reason,
    List<String>? scope,
  }) {
    return BlacklistRecord(
      uid: uid ?? this.uid,
      username: username ?? this.username,
      createdAt: createdAt ?? this.createdAt,
      reason: reason ?? this.reason,
      scope: scope ?? this.scope,
    );
  }

  /// 规范化 scope 列表：仅保留已知值并去重保序。
  static List<String> normalizeScopes(Iterable<Object?> raw) {
    final out = <String>[];
    final seen = <String>{};
    for (final item in raw) {
      final value = item?.toString().trim() ?? '';
      if (value.isEmpty || !knownScopes.contains(value)) continue;
      if (seen.add(value)) out.add(value);
    }
    return out;
  }

  Map<String, dynamic> toJson() => {
        'uid': uid,
        'username': username,
        'createdAt': createdAt,
        'reason': reason,
        'scope': List<String>.from(scope),
      };
}
