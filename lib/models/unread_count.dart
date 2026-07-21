class UnreadCount {
  const UnreadCount({
    this.newpm = 0,
    this.newprompt = 0,
    this.newmypost = 0,
  });

  factory UnreadCount.fromJson(Map<String, dynamic> json) {
    int parseInt(dynamic value) {
      if (value == null) return 0;
      if (value is int) return value;
      if (value is String) return int.tryParse(value) ?? 0;
      return 0;
    }

    return UnreadCount(
      newpm: parseInt(json['newpm']),
      newprompt: parseInt(json['newprompt']),
      newmypost: parseInt(json['newmypost']),
    );
  }

  final int newpm;
  final int newprompt;
  final int newmypost;

  int get total => newpm + newprompt + newmypost;

  String get displayBadge => total > 99 ? '99+' : '$total';

  static const zero = UnreadCount();

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UnreadCount &&
          runtimeType == other.runtimeType &&
          newpm == other.newpm &&
          newprompt == other.newprompt &&
          newmypost == other.newmypost;

  @override
  int get hashCode => newpm.hashCode ^ newprompt.hashCode ^ newmypost.hashCode;
}
