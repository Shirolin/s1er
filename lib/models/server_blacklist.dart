import 'package:html/parser.dart' show parse;

class ServerBlacklistUser {
  const ServerBlacklistUser({required this.uid, required this.username});

  final String uid;
  final String username;
}

class ServerBlacklistPage {
  const ServerBlacklistPage({
    required this.items,
    required this.page,
    required this.totalPages,
  });

  final List<ServerBlacklistUser> items;
  final int page;
  final int totalPages;

  static ServerBlacklistPage fromHtml(String html, {required int page}) {
    final document = parse(html);
    if (document.querySelector('#friend_ul') == null) {
      throw const FormatException('网页黑名单页面结构异常');
    }
    final items = <ServerBlacklistUser>[];
    final seen = <String>{};
    for (final node in document.querySelectorAll('#friend_ul li')) {
      final link = node.querySelector('h4 > a') ?? node.querySelector('a');
      if (link == null) continue;
      final href = link.attributes['href'] ?? '';
      final uid = _extractUid(href);
      if (uid == null || !seen.add(uid)) continue;
      final username = link.text.trim();
      items.add(ServerBlacklistUser(uid: uid, username: username));
    }

    var totalPages = page;
    final pageLabel = document.querySelector('.pg > label');
    final labelMax = RegExp(r'\d+')
        .allMatches(pageLabel?.querySelector('span')?.text ?? '')
        .map((match) => int.parse(match.group(0)!))
        .fold<int>(page, (max, value) => max > value ? max : value);
    if (labelMax > totalPages) totalPages = labelMax;
    for (final link in document.querySelectorAll('.pg a')) {
      final href = link.attributes['href'] ?? '';
      final match = RegExp(r'(?:[?&]|^)page=(\d+)').firstMatch(href);
      if (match != null) {
        totalPages = totalPages > int.parse(match.group(1)!)
            ? totalPages
            : int.parse(match.group(1)!);
      }
    }
    return ServerBlacklistPage(
      items: items,
      page: page,
      totalPages: totalPages,
    );
  }

  static String? _extractUid(String href) {
    final uri = Uri.tryParse(href);
    final queryUid = uri?.queryParameters['uid'];
    if (queryUid != null && RegExp(r'^\d+$').hasMatch(queryUid)) {
      return queryUid;
    }
    final match = RegExp(r'[?&]uid=(\d+)').firstMatch(href);
    return match?.group(1);
  }
}
