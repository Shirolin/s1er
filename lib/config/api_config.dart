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

  // API module names
  static const String moduleForumIndex = 'forumindex';
  static const String moduleForumDisplay = 'forumdisplay';
  static const String moduleViewThread = 'viewthread';
  static const String moduleLogin = 'login';
  static const String moduleSendMessage = 'sendpm';
  static const String moduleProfile = 'profile';
}
