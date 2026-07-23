class S1Constants {
  static const String appName = 'S1er';

  /// 客户端下载页占位（小尾巴 `[url]`；上架后可按渠道替换）。
  /// 指向官网（CF Pages），对国内访问更友好；GitHub 作为后备。
  static const String downloadUrl = 'https://s1er.pages.dev';

  static const String mobileUserAgent =
      'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) '
      'AppleWebKit/605.1.15 (KHTML, like Gecko) '
      'Version/17.0 Mobile/15E148 Safari/604.1';

  /// 桌面 UA：论坛附件上传需刮桌面编辑器里的 `hash` / `post_params`，
  /// 手机 UA 常落到触屏模板，缺少 swfupload 凭据。
  static const String desktopUserAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';

  /// API / HTML 等论坛交互请求的全局上限（保护 S1 服务器）。
  static const int maxRequestsPerSecond = 2;

  /// 图片字节等媒体请求的独立配额（与 API 同为 2/s，但不共用队列，避免互相堵）。
  static const int maxMediaRequestsPerSecond = 2;

  static const int cookieRefreshIntervalMinutes = 30;
  static const Duration cacheExpiry = Duration(minutes: 5);

  /// 读帖页状态会话缓存（离开详情后短时保留，避免返回同帖重拉）。
  static const Duration postSessionCacheExpiry = Duration(minutes: 2);

  /// 帖子详情页每页帖数的兜底值。
  /// 权威来源是 API 的 `ppp` 字段（viewthread，实际为 40）；仅在拿不到
  /// API 值时（如帖子列表只有列表数据、无 `ppp`）使用此兜底值。
  /// 注意：勿与 forumdisplay 的 `tpp`(=50，主题列表每页数) 混用。
  static const int postsPerPageFallback = 40;

  /// 图片磁盘缓存默认上限（运行时由设置 [imageCacheLimitMb] 覆盖）。
  static const int defaultImageCacheLimitMb = 256;
  static const int maxImageCacheBytes = defaultImageCacheLimitMb * 1024 * 1024;

  /// 每楼层默认 inline 图片显示上限（0 = 不限制）。
  static const int defaultMaxImagesPerPost = 10;

  /// 可选磁盘缓存上限档位（MB）。
  static const List<int> imageCacheLimitOptionsMb = [100, 256, 512];

  /// Inline 图片解码宽度 clamp（物理像素）。
  static const int inlineImageDecodeMinPx = 200;
  static const int inlineImageDecodeMaxPx = 1600;

  /// 多楼层分享：层数软顶（UX 刹车；真正 OOM 靠像素硬顶）。
  static const int shareMaxSelectedFloors = 10;

  /// 分享卡导出像素硬顶（宽×高）。约等于常见 GPU 纹理高 8192 × 导出宽 1800（3×）。
  static const int shareCaptureMaxPixels = 8192 * 1800;

  /// 低于此像素且仅 1 楼时走单次 [RepaintBoundary.toImage]；否则按楼分块拼接。
  /// 取常见 4096 纹理高 × 默认导出宽 900（1.5×）。
  static const int shareCaptureChunkThresholdPixels = 4096 * 900;

  /// 识别表情包路径的特征
  static bool isEmoticon(String url) {
    final lowerUrl = url.toLowerCase();
    if (lowerUrl.contains('static.stage1st.com/image/smiley') ||
        lowerUrl.contains('/image/smiley/')) {
      return true;
    }
    return lowerUrl.contains('face2017') ||
        lowerUrl.contains('carton2017') ||
        lowerUrl.contains('animal2017') ||
        lowerUrl.contains('device2017') ||
        lowerUrl.contains('goose2017') ||
        lowerUrl.contains('bundam2017');
  }
}
