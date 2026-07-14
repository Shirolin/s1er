class DarkRoomEntry {
  const DarkRoomEntry({
    required this.cid,
    required this.uid,
    required this.username,
    required this.operatorId,
    required this.operatorName,
    required this.action,
    required this.reason,
    required this.datelineRaw,
    required this.groupExpiryRaw,
  });

  factory DarkRoomEntry.fromJson(Map<String, dynamic> json) {
    return DarkRoomEntry(
      cid: json['cid']?.toString() ?? '',
      uid: json['uid']?.toString() ?? '',
      username: json['username']?.toString() ?? '',
      operatorId: json['operatorid']?.toString() ?? '',
      operatorName: json['operator']?.toString() ?? '',
      action: json['action']?.toString() ?? '',
      reason: json['reason']?.toString() ?? '',
      datelineRaw: json['dateline']?.toString() ?? '',
      groupExpiryRaw: json['groupexpiry']?.toString() ?? '',
    );
  }

  final String cid;
  final String uid;
  final String username;
  final String operatorId;
  final String operatorName;
  final String action;
  final String reason;
  final String datelineRaw;
  final String groupExpiryRaw;

  bool get isPermanent =>
      groupExpiryRaw.contains('永不过期') || groupExpiryRaw.trim().isEmpty;
}

class DarkRoomPage {
  const DarkRoomPage({
    required this.items,
    this.nextCursor,
    this.dataExist,
    this.hasMore = false,
  });

  static const empty = DarkRoomPage(items: []);

  final List<DarkRoomEntry> items;
  final String? nextCursor;
  final String? dataExist;
  final bool hasMore;
}
