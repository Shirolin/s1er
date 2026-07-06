import 'package:html/parser.dart' as html_parser;
import 'package:html/dom.dart';
import '../models/thread.dart';
import '../models/post.dart';
import '../config/api_config.dart';
import 'http_client.dart';

class HtmlParserService {
  final S1HttpClient _httpClient;

  HtmlParserService(this._httpClient);

  /// Parse thread list from raw HTML string (static, for testing).
  static List<Thread> parseThreadListHtml(String html, {required String fid}) {
    final doc = html_parser.parse(html);
    final threads = <Thread>[];

    final threadElements =
        doc.querySelectorAll('li[id^="normalthread_"], .normalthread');

    for (final element in threadElements) {
      try {
        final link = element.querySelector('a[href*="thread-"]');
        if (link == null) continue;

        final href = link.attributes['href'] ?? '';
        final tidMatch = RegExp(r'thread-(\d+)').firstMatch(href);
        if (tidMatch == null) continue;

        final authorEl =
            element.querySelector('.by cite, .authortd a, td.by a');
        final numEl = element.querySelector('.num a, .num em');

        int views = 0;
        int replies = 0;
        if (numEl != null) {
          final numText = numEl.parent?.text ?? '';
          final nums = RegExp(r'(\d+)').allMatches(numText).toList();
          if (nums.length >= 2) {
            views = int.tryParse(nums[0].group(0)!) ?? 0;
            replies = int.tryParse(nums[1].group(0)!) ?? 0;
          }
        }

        threads.add(Thread(
          tid: tidMatch.group(1)!,
          subject: link.text.trim(),
          author: authorEl?.text.trim() ?? '',
          authorId: '',
          dateline: 0,
          views: views,
          replies: replies,
          fid: fid,
        ));
      } catch (_) {
        continue;
      }
    }

    return threads;
  }

  /// Parse post list from raw HTML string (static, for testing).
  static List<Post> parsePostListHtml(String html) {
    final doc = html_parser.parse(html);
    final posts = <Post>[];

    final postElements =
        doc.querySelectorAll('#postlist > div[id^="post_"]');

    int floor = 0;
    for (final element in postElements) {
      floor++;

      try {
        String author = '';
        String content = '';

        if (element.id.startsWith('post_')) {
          // Full post container
          final authorEl = element.querySelector('.pi a.xw1, .authortd a');
          author = authorEl?.text.trim() ?? '';

          final messageEl =
              element.querySelector('.message, .postmessage, .t_f');
          content = messageEl?.innerHtml ?? '';
        } else {
          // Direct message element
          content = element.innerHtml;
          Element? parent = element.parent;
          while (parent != null) {
            if (parent.id.startsWith('post_')) {
              final authorEl =
                  parent.querySelector('.pi a.xw1, .authortd a');
              author = authorEl?.text.trim() ?? '';
              break;
            }
            parent = parent.parent;
          }
        }

        posts.add(Post(
          pid: '',
          message: content,
          author: author,
          authorId: '',
          dateline: 0,
          floor: floor,
        ));
      } catch (_) {
        continue;
      }
    }

    return posts;
  }

  /// Extract formhash from raw HTML string (static, for testing).
  static String extractFormhash(String html) {
    final doc = html_parser.parse(html);
    final formhashInput = doc.querySelector('input[name="formhash"]');
    return formhashInput?.attributes['value'] ?? '';
  }

  Future<List<Thread>> getThreadList(String fid, {int page = 1}) async {
    final url =
        '${ApiConfig.baseUrl}/forum.php?mobile=2&fid=$fid&page=$page';
    final response = await _httpClient.get(url);
    final html = response.data is String
        ? response.data as String
        : response.data.toString();
    return parseThreadListHtml(html, fid: fid);
  }

  Future<List<Post>> getPosts(String tid, {int page = 1}) async {
    final url =
        '${ApiConfig.baseUrl}/thread-$tid-$page-1.html?mobile=2';
    final response = await _httpClient.get(url);
    final html = response.data is String
        ? response.data as String
        : response.data.toString();
    return parsePostListHtml(html);
  }

  Future<String> getFormhash(String tid) async {
    final url =
        '${ApiConfig.baseUrl}/thread-$tid-1-1.html?mobile=2';
    final response = await _httpClient.get(url);
    final html = response.data is String
        ? response.data as String
        : response.data.toString();
    return extractFormhash(html);
  }
}
