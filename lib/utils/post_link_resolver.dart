import '../config/api_config.dart';
import '../config/resource_domains.dart';
import '../models/thread_destination.dart';
import 'thread_navigation.dart';

/// 正文链接的处理结果。
sealed class PostLinkResolution {
  const PostLinkResolution();
}

/// 可由现有 GoRouter 页面原生打开的论坛链接。
class InternalPostLink extends PostLinkResolution {
  const InternalPostLink(this.location);

  final String location;
}

/// 需交给系统浏览器打开的链接。
class ExternalPostLink extends PostLinkResolution {
  const ExternalPostLink(this.uri);

  final Uri uri;
}

/// 无法解析的链接；调用方应安全忽略。
class InvalidPostLink extends PostLinkResolution {
  const InvalidPostLink();
}

/// 将帖子正文中的链接映射到 App 路由或外部 URI。
abstract final class PostLinkResolver {
  static final _threadPath = RegExp(
    r'(?:^|/)thread-(\d+)-(\d+)(?:-\d+)?\.html$',
    caseSensitive: false,
  );
  static final _forumPath = RegExp(
    r'(?:^|/)forum-(\d+)-(\d+)(?:-\d+)?\.html$',
    caseSensitive: false,
  );
  /// Discuz 锚点：`#pid123` 或旧站纯数字 `#16352875`。
  static final _fragmentPid = RegExp(r'^(?:pid)?(\d+)$', caseSensitive: false);
  static final _leadingDigits = RegExp(r'^(\d+)');
  /// 脏 tid 里嵌的页码，如 `874342-fpage-3-page-2.html`。
  static final _embeddedPage = RegExp(r'-page-(\d+)', caseSensitive: false);

  static PostLinkResolution resolve(String rawUrl) {
    final uri = _resolveUri(rawUrl);
    if (uri == null) return const InvalidPostLink();

    if (!ResourceDomains.isForumHost(uri.host)) {
      return ExternalPostLink(uri);
    }

    final location = _resolveForumLocation(uri);
    return location == null
        ? ExternalPostLink(uri)
        : InternalPostLink(location);
  }

  static Uri? _resolveUri(String rawUrl) {
    var value = rawUrl.trim();
    // 旧帖 HTML 常见双重实体：`&amp;amp;` → 需解到真正的 `&`。
    while (value.contains('&amp;')) {
      value = value.replaceAll('&amp;', '&');
    }
    if (value.isEmpty) return null;

    final baseUri = Uri.parse('${ApiConfig.baseUrl}/');
    final candidate =
        value.startsWith('//') ? '${baseUri.scheme}:$value' : value;
    final parsed = Uri.tryParse(candidate);
    if (parsed == null) return null;
    return parsed.hasScheme ? parsed : baseUri.resolveUri(parsed);
  }

  static String? _resolveForumLocation(Uri uri) {
    if (_isForumHome(uri)) return '/';

    final query = uri.queryParameters;
    final mod = query['mod'] ?? query['module'];
    final rawTid = query['tid'];
    final tid = _normalizeId(rawTid);
    final tidPage = _pageFromMessyValue(rawTid);

    if ((mod == 'viewthread' || mod == 'redirect') && tid != null) {
      return _threadLocation(tid, uri, fallbackPage: tidPage);
    }

    // Discuz 旧版直链：read.php / viewthread.php?tid=
    if (_isLegacyThreadScript(uri.path) && tid != null) {
      return _threadLocation(tid, uri, fallbackPage: tidPage);
    }

    final ptid = _normalizeId(query['ptid']);
    if (query['goto'] == 'findpost' && ptid != null) {
      return _threadLocation(ptid, uri);
    }

    final fid = _normalizeId(query['fid']);
    if (mod == 'forumdisplay' && fid != null) {
      return _forumLocation(fid, query['page']);
    }

    if (_isLegacyForumScript(uri.path) && fid != null) {
      return _forumLocation(fid, query['page']);
    }

    if (uri.path.endsWith('home.php') &&
        mod == 'space' &&
        _normalizeId(query['uid']) != null) {
      return _userSpaceLocation(query);
    }

    final threadMatch = _threadPath.firstMatch(uri.path);
    if (threadMatch != null) {
      return _threadLocation(
        threadMatch.group(1)!,
        uri,
        fallbackPage: threadMatch.group(2),
      );
    }

    final forumMatch = _forumPath.firstMatch(uri.path);
    if (forumMatch != null) {
      return _forumLocation(forumMatch.group(1)!, forumMatch.group(2));
    }

    return null;
  }

  static bool _isLegacyThreadScript(String path) {
    final lower = path.toLowerCase();
    return lower.endsWith('read.php') || lower.endsWith('viewthread.php');
  }

  static bool _isLegacyForumScript(String path) =>
      path.toLowerCase().endsWith('forumdisplay.php');

  static bool _isForumHome(Uri uri) {
    final path = uri.path.replaceFirst(RegExp(r'/+$'), '');
    return (path.isEmpty || path == '/2b') && uri.queryParameters.isEmpty;
  }

  static String _threadLocation(
    String tid,
    Uri uri, {
    String? fallbackPage,
  }) {
    final pid = _normalizeId(uri.queryParameters['pid']) ??
        _fragmentPid.firstMatch(uri.fragment)?.group(1);
    if (pid != null) return ThreadRouteCodec.encodePath(ThreadPost(tid, pid));

    final page = _validPage(uri.queryParameters['page'] ?? fallbackPage);
    if (page != null) {
      return ThreadRouteCodec.encodePath(ThreadPage(tid, page));
    }
    return ThreadRouteCodec.encodePath(ResumeThread(tid));
  }

  static String? _forumLocation(String fid, String? pageValue) {
    // ForumListScreen 现有路由未表达列表页码，避免点击后悄悄落到错误页。
    final page = _validPage(pageValue);
    if (pageValue != null && page == null) return null;
    if (page != null && page > 1) return null;
    return '/forum/$fid';
  }

  static String? _userSpaceLocation(Map<String, String> query) {
    final page = _validPage(query['page']);
    if (query['page'] != null && page == null) return null;
    if (page != null && page > 1) return null;

    final action = query['do'];
    if (action != null && action.isNotEmpty && action != 'thread') return null;
    final tab = query['type'] == 'reply' ? 1 : 0;
    return '/user-space/${_normalizeId(query['uid'])}?tab=$tab';
  }

  /// 从 `606858.html` / `911581-page-1.html` / `562154-.html` 取出纯数字 id。
  static String? _normalizeId(String? value) {
    if (value == null || value.isEmpty) return null;
    return _leadingDigits.firstMatch(value)?.group(1);
  }

  static String? _pageFromMessyValue(String? value) {
    if (value == null || value.isEmpty) return null;
    // 取最后一个 `-page-N`，避开 `fpage` 误伤（`-fpage-` 不含 `-page-`）。
    String? page;
    for (final match in _embeddedPage.allMatches(value)) {
      page = match.group(1);
    }
    return page;
  }

  static int? _validPage(String? value) {
    final page = int.tryParse(value ?? '');
    return page != null && page >= 1 ? page : null;
  }
}
