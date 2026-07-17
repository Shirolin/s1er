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
  static final _fragmentPid = RegExp(r'^pid(\d+)$', caseSensitive: false);
  static final _digits = RegExp(r'^\d+$');

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
    final value = rawUrl.trim().replaceAll('&amp;', '&');
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
    final tid = query['tid'];
    if ((mod == 'viewthread' || mod == 'redirect') && _isId(tid)) {
      return _threadLocation(tid!, uri);
    }

    // Discuz 旧版直链：read.php / viewthread.php?tid=
    if (_isLegacyThreadScript(uri.path) && _isId(tid)) {
      return _threadLocation(tid!, uri);
    }

    final ptid = query['ptid'];
    if (query['goto'] == 'findpost' && _isId(ptid)) {
      return _threadLocation(ptid!, uri);
    }

    if (mod == 'forumdisplay' && _isId(query['fid'])) {
      return _forumLocation(query['fid']!, query['page']);
    }

    if (_isLegacyForumScript(uri.path) && _isId(query['fid'])) {
      return _forumLocation(query['fid']!, query['page']);
    }

    if (uri.path.endsWith('home.php') &&
        mod == 'space' &&
        _isId(query['uid'])) {
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
    final path = uri.path.replaceFirst(RegExp(r'/$'), '');
    return (path.isEmpty || path == '/2b') && uri.queryParameters.isEmpty;
  }

  static String _threadLocation(
    String tid,
    Uri uri, {
    String? fallbackPage,
  }) {
    final pid = uri.queryParameters['pid'] ??
        _fragmentPid.firstMatch(uri.fragment)?.group(1);
    if (_isId(pid)) return ThreadRouteCodec.encodePath(ThreadPost(tid, pid!));

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
    return '/user-space/${query['uid']}?tab=$tab';
  }

  static bool _isId(String? value) => value != null && _digits.hasMatch(value);

  static int? _validPage(String? value) {
    final page = int.tryParse(value ?? '');
    return page != null && page >= 1 ? page : null;
  }
}
