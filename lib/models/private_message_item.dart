import '../config/api_config.dart';
import 'user.dart';

class PrivateMessageItem {
  PrivateMessageItem({
    required this.touid,
    required this.partnerName,
    required this.preview,
    required this.dateline,
    required this.isOutgoing,
    this.avatarUrl,
  });

  factory PrivateMessageItem.fromApiJson(Map<String, dynamic> json) {
    final touid = _firstNonEmpty([
      json['touid'],
      json['msgtoid'],
      json['uid'],
    ]);
    final msgfrom = json['msgfrom']?.toString() ?? '';
    final msgfromid = _firstNonEmpty([
      json['msgfromid'],
      json['authorid'],
    ]);
    final message = _decodeHtml(
      _firstNonEmpty([
        json['message'],
        json['lastmessage'],
        json['lastsummary'],
        json['summary'],
        json['subject'],
      ]),
    );
    final dateline = _parseDateline(json);
    final isOutgoing =
        msgfromid.isNotEmpty && touid.isNotEmpty && msgfromid != touid;

    final partnerName = isOutgoing
        ? _firstNonEmpty([
            json['tousername'],
            json['touuser'],
            json['msgto'],
            json['toname'],
          ])
        : msgfrom;
    final avatarUid = touid;
    final rawAvatar = _firstNonEmpty([
      json['avatar'],
      json['member_avatar'],
      json['msgfromavatar'],
    ]);
    final avatarUrl = rawAvatar.isNotEmpty
        ? User.resolveAvatarUrl(rawAvatar, size: 'small')
        : _avatarFromUid(avatarUid);

    return PrivateMessageItem(
      touid: touid,
      partnerName: partnerName.isNotEmpty ? partnerName : '用户$avatarUid',
      preview: message,
      dateline: dateline,
      isOutgoing: isOutgoing,
      avatarUrl: avatarUrl,
    );
  }

  final String touid;
  final String partnerName;
  final String preview;
  final int dateline;
  final bool isOutgoing;
  final String? avatarUrl;

  String get browserUrl =>
      '${ApiConfig.baseUrl}/home.php?mod=space&do=pm&subop=view&touid=$touid';

  static String? avatarUrlForUid(String uid) => _avatarFromUid(uid);

  static String _firstNonEmpty(List<dynamic> values) {
    for (final value in values) {
      final text = value?.toString().trim() ?? '';
      if (text.isNotEmpty) return text;
    }
    return '';
  }

  static String? _avatarFromUid(String uid) {
    if (uid.isEmpty) return null;
    final padded = uid.padLeft(9, '0');
    final seg1 = padded.substring(0, 3);
    final seg2 = padded.substring(3, 5);
    final seg3 = padded.substring(5, 7);
    final seg4 = padded.substring(7);
    return 'https://avatar.stage1st.com/$seg1/$seg2/$seg3/${seg4}_avatar_small.jpg';
  }

  static int _parseDateline(Map<String, dynamic> json) {
    final ts = int.tryParse(json['dateline']?.toString() ?? '');
    if (ts != null && ts > 0) return ts;
    final dbTs = int.tryParse(json['dbdateline']?.toString() ?? '');
    if (dbTs != null && dbTs > 0) return dbTs;
    final date = _firstNonEmpty([
      json['date'],
      json['pmdate'],
      json['postdatetime'],
      json['time'],
    ]);
    if (date.isEmpty) return 0;
    return _parseLooseDateString(date);
  }

  static int _parseLooseDateString(String s) {
    final normalized = s.trim().replaceAll('/', '-');
    if (normalized.isEmpty) return 0;
    try {
      final parts = normalized.split(RegExp(r'\s+'));
      final dateParts = parts.first.split('-');
      if (dateParts.length == 3) {
        final year = int.parse(dateParts[0]);
        final month = int.parse(dateParts[1]);
        final day = int.parse(dateParts[2]);
        var hour = 0;
        var minute = 0;
        if (parts.length > 1) {
          final timeParts = parts[1].split(':');
          if (timeParts.length >= 2) {
            hour = int.parse(timeParts[0]);
            minute = int.parse(timeParts[1]);
          }
        }
        return DateTime(year, month, day, hour, minute)
                .millisecondsSinceEpoch ~/
            1000;
      }
    } catch (_) {}
    try {
      return DateTime.parse(normalized).millisecondsSinceEpoch ~/ 1000;
    } catch (_) {
      return 0;
    }
  }

  static String _decodeHtml(String text) {
    return text
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#039;', "'")
        .replaceAll('&#39;', "'")
        .replaceAll('&nbsp;', ' ')
        .replaceAll(RegExp(r'<[^>]+>'), '')
        .trim();
  }
}
