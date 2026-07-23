class ApiConfig {
  static const String baseUrl = 'https://stage1st.com/2b';
  static const String mobileApiUrl = '$baseUrl/api/mobile/index.php';
  static const String loginUrl = '$baseUrl/member.php?mod=logging&action=login';
  static const String forumPostUrl = '$baseUrl/forum.php';

  /// Discuz 回复 POST 所需的 Referer（来路校验）
  static String forumReplyReferer({
    required String fid,
    required String tid,
    String reppost = '0',
  }) =>
      '$forumPostUrl?mod=post&action=reply&fid=$fid&tid=$tid'
      '&reppost=$reppost&extra=&replysubmit=yes&mobile=2&handlekey=postform';

  /// Discuz 收藏 POST 所需的 Referer（来路校验）
  static String favoriteThreadReferer(String tid) =>
      '$forumPostUrl?mod=viewthread&tid=$tid&extra=page%3D1&mobile=2';

  static String favoriteForumReferer(String fid) =>
      '$forumPostUrl?mod=forumdisplay&fid=$fid&mobile=2';

  /// Discuz 评分 POST 所需的 Referer（来路校验）
  static String forumRateReferer(String tid, String pid) =>
      '$forumPostUrl?mod=viewthread&tid=$tid&page=0#pid$pid';

  static String reportFormUrl({
    required String tid,
    required String pid,
    String? fid,
  }) {
    final params = <String, String>{
      'mod': 'report',
      'rtype': 'post',
      'rid': pid,
      'tid': tid,
      'inajax': '1',
      't': DateTime.now().millisecondsSinceEpoch.toString(),
    };
    if (fid != null && fid.isNotEmpty) params['fid'] = fid;
    return '$baseUrl/misc.php?${Uri(queryParameters: params).query}';
  }

  static String reportSubmitUrl() => '$baseUrl/misc.php?mod=report&inajax=1';

  static String forumReportReferer(String tid, int page) =>
      '$forumPostUrl?mod=viewthread&tid=$tid&page=$page&mobile=2';

  static String editPostFormUrl({
    required String fid,
    required String tid,
    required String pid,
  }) =>
      '$forumPostUrl?mod=post&action=edit&fid=$fid&tid=$tid&pid=$pid';

  static String editPostSubmitUrl() =>
      '$forumPostUrl?mod=post&action=edit&editsubmit=yes&inajax=yes'
      '&wysiwyg=1&delete=0';

  /// 回复编辑页（刮取论坛附件上传 hash/uid）。
  static String replyEditorUrl({required String tid}) =>
      '$forumPostUrl?mod=post&action=reply&inajax=yes'
      '&tid=${Uri.encodeQueryComponent(tid)}';

  /// 发新帖编辑页（刮取论坛附件上传 hash/uid）。
  static String newThreadEditorUrl({required String fid}) =>
      '$forumPostUrl?mod=post&action=newthread&fid=${Uri.encodeQueryComponent(fid)}'
      '&inajax=yes';

  /// Discuz swfupload 图片附件上传。
  static String forumAttachmentUploadUrl({required String fid}) =>
      '$baseUrl/misc.php?mod=swfupload&action=swfupload&operation=upload'
      '&fid=${Uri.encodeQueryComponent(fid)}';

  /// 上传后拉取缩略图（单图 imagelist）。
  static String forumAttachmentImageListUrl({
    required String aids,
    required String fid,
    String ajaxTarget = 'WU_FILE_0',
  }) =>
      '$forumPostUrl?mod=ajax&action=imagelist&type=single'
      '&pid=0&aids=${Uri.encodeQueryComponent(aids)}'
      '&fid=${Uri.encodeQueryComponent(fid)}'
      '&inajax=1&ajaxtarget=${Uri.encodeQueryComponent(ajaxTarget)}';

  /// 含论坛附件时的网页回复提交。
  static String webReplySubmitUrl({
    required String fid,
    required String tid,
  }) =>
      '$forumPostUrl?mod=post&action=reply&fid=${Uri.encodeQueryComponent(fid)}'
      '&tid=${Uri.encodeQueryComponent(tid)}'
      '&extra=&replysubmit=yes&inajax=1';

  /// 含论坛附件时的网页发新帖提交。
  static String webNewThreadSubmitUrl({required String fid}) =>
      '$forumPostUrl?mod=post&action=newthread'
      '&fid=${Uri.encodeQueryComponent(fid)}'
      '&extra=&topicsubmit=yes&inajax=1';

  // API module names
  static const String moduleForumIndex = 'forumindex';
  static const String moduleForumDisplay = 'forumdisplay';
  static const String moduleViewThread = 'viewthread';
  static const String moduleLogin = 'login';
  static const String moduleSendMessage = 'sendpm';
  static const String moduleMyPm = 'mypm';
  static const String moduleMyNoteList = 'mynotelist';
  static const String moduleProfile = 'profile';
  static const String moduleMyFavThread = 'myfavthread';
  static const String moduleMyFavForum = 'myfavforum';
  static const String moduleFavThread = 'favthread';
  static const String moduleFavForum = 'favforum';
  static const String moduleSendReply = 'sendreply';
  static const String moduleNewThread = 'newthread';
  static const String moduleFriend = 'friend';

  /// 好友 Mobile API 使用 version=1（实测响应 `Version:"1"`）。
  static const String friendApiVersion = '1';

  /// Discuz 每日签到插件（GET，需 formhash；会产生服务端写入）。
  static String dailyAttendanceUrl({required String formhash}) =>
      '$baseUrl/study_daily_attendance-daily_attendance.html'
      '?inajax=1&formhash=${Uri.encodeComponent(formhash)}';

  /// 小黑屋公开处罚列表（cursor 分页）。
  static String darkRoomUrl({String? cursor}) {
    final cid = cursor == null || cursor.isEmpty
        ? ''
        : '&cid=${Uri.encodeComponent(cursor)}';
    return '$forumPostUrl?mod=misc&action=showdarkroom&ajaxdata=json$cid';
  }

  static String friendsBrowserUrl(String uid) =>
      '$baseUrl/home.php?mod=space&uid=$uid&do=friend&view=me&mobile=2';

  static String threadBrowserUrl({required String tid, required int page}) =>
      '$baseUrl/thread-$tid-$page-1.html';

  static String forumBrowserUrl({required String fid, required int page}) =>
      '$baseUrl/forum-$fid-$page.html';

  static String pmConversationBrowserUrl({
    required String touid,
    required int page,
  }) =>
      '$baseUrl/home.php?mod=space&do=pm&subop=view&touid=$touid&page=$page';

  static String favoriteBrowserUrl({
    String? uid,
    String? type,
    required int page,
  }) {
    final params = <String, String>{
      'mod': 'space',
      if (uid != null && uid.isNotEmpty) 'uid': uid,
      'do': 'favorite',
      'view': 'me',
      if (type != null && type.isNotEmpty) 'type': type,
      'page': page.toString(),
      'mobile': '2',
    };
    return '$baseUrl/home.php?${Uri(queryParameters: params).query}';
  }

  static String userSpaceBrowserUrl({
    required String uid,
    required String type,
    required int page,
  }) {
    final params = <String, String>{
      'mod': 'space',
      'uid': uid,
      'do': 'thread',
      'view': 'me',
      'type': type,
      'from': 'space',
      'page': page.toString(),
    };
    return '$baseUrl/home.php?${Uri(queryParameters: params).query}';
  }

  static String messagesBrowserUrl({
    required bool isNotice,
    String noticeFeed = 'mypost',
    required int page,
  }) {
    final params = <String, String>{
      'mod': 'space',
      'do': isNotice ? 'notice' : 'pm',
      if (isNotice) ...{
        'view': noticeFeed,
        'type': '',
        'isread': '1',
      } else
        'filter': 'privatepm',
      'page': page.toString(),
    };
    return '$baseUrl/home.php?${Uri(queryParameters: params).query}';
  }

  static String serverBlacklistUrl({required String uid, required int page}) =>
      '$baseUrl/home.php?mod=space&do=friend&view=blacklist'
      '&uid=${Uri.encodeQueryComponent(uid)}&page=$page&mobile=2';

  static String darkRoomBrowserUrl() =>
      '$forumPostUrl?mod=misc&action=showdarkroom&mobile=2';

  /// Discuz 搜索（HTML）：主题 / 用户。
  static String searchForumUrl({int? page}) {
    final pageQuery = page == null ? '' : '&page=$page';
    return '$baseUrl/search.php?searchsubmit=yes&mod=forum$pageQuery';
  }

  static String searchUserUrl() =>
      '$baseUrl/search.php?searchsubmit=yes&mod=user';
}
