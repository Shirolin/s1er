/// S1 资源域名统一配置
///
/// 论坛历史上换过多次资源域名，所有域名规则集中在此文件管理。
/// Flutter 端（http_client / image_viewer）和代理端（proxy_server）共享此配置。
/// 新增/修改域名只需改动此文件。
library;

import 'env_config.dart';

// ──────────────────────── 资源类型 ────────────────────────

enum ResourceType {
  /// API 主域名 → 走代理默认路由，需要 Cookie
  api,

  /// 需要认证的图片资源 → 走代理 /img-proxy，需要 Cookie + Referer
  authImage,

  /// 公开资源（表情包等）→ 浏览器直加载，无需认证
  publicAsset,
}

// ──────────────────────── 域名规则 ────────────────────────

class DomainRule {
  const DomainRule({
    required this.host,
    required this.type,
    this.referer,
  });

  /// 域名（精确匹配）
  final String host;

  /// 资源类型
  final ResourceType type;

  /// 自定义 Referer（仅 authImage 生效），null 时使用默认值
  final String? referer;
}

// ──────────────────────── 配置中心 ────────────────────────

class ResourceDomains {
  ResourceDomains._();

  /// 代理服务器端口（与 [EnvConfig.proxyPort] 统一）
  static int get proxyPort => EnvConfig.proxyPort;

  /// API 主域名（用于代理默认路由）
  static const String apiHost = 'stage1st.com';

  /// 论坛站点域名（含历史域名），用于识别可由客户端原生处理的站内链接。
  ///
  /// 这与资源域名规则分开：图片/CDN 的加载、代理和 Cookie 策略不应决定
  /// 一个链接是否属于论坛页面。
  ///
  /// 历史域名备忘：`*.saraba1st.com` 为更早主站；现已迁至 `*.stage1st.com`。
  static const Set<String> forumHosts = {
    apiHost,
    'www.stage1st.com',
    'bbs.stage1st.com',
    'saraba1st.com',
    'www.saraba1st.com',
    'bbs.saraba1st.com',
  };

  /// 认证 Cookie 前缀（用于过滤无关 Cookie）
  static const String cookiePrefix = 'B7Y9_2f85_';

  /// 认证图片请求的默认 Referer
  static const String defaultReferer = 'https://stage1st.com/';

  /// 域名规则表（按顺序匹配，第一个命中即生效）
  ///
  /// 新增域名时，在此处添加一行即可。
  /// 历史域名备忘：
  ///   - bbs.stage1st.com（旧主域名，含附件和表情）
  ///   - img1.stage1st.com（旧图片 CDN）
  static const List<DomainRule> rules = [
    // API
    DomainRule(host: 'stage1st.com', type: ResourceType.api),
    DomainRule(host: 'www.stage1st.com', type: ResourceType.api),

    // 需认证的图片
    DomainRule(host: 'img.stage1st.com', type: ResourceType.authImage),

    // 公开资源（表情包、头像等）
    DomainRule(host: 'static.stage1st.com', type: ResourceType.publicAsset),
    DomainRule(host: 'avatar.stage1st.com', type: ResourceType.publicAsset),
  ];

  // ──────────────────────── 查询方法 ────────────────────────

  /// 根据 host 查找匹配的规则，未匹配返回 null
  static DomainRule? match(String host) {
    for (final rule in rules) {
      if (rule.host == host) return rule;
    }
    return null;
  }

  /// 是否为论坛当前或历史站点域名。
  static bool isForumHost(String host) =>
      forumHosts.contains(host.toLowerCase());

  /// 该 host 是否需要通过 Dio 加载（带 Cookie）
  static bool requiresAuth(String host) {
    final rule = match(host);
    return rule?.type == ResourceType.api ||
        rule?.type == ResourceType.authImage;
  }

  /// 该 host 是否需要走代理（Web 端 CORS 限制）
  static bool requiresProxy(String host) {
    final rule = match(host);
    return rule?.type == ResourceType.api ||
        rule?.type == ResourceType.authImage;
  }

  /// 获取认证图片的 Referer
  static String getReferer(String host) {
    final rule = match(host);
    return rule?.referer ?? defaultReferer;
  }

  /// `/img-proxy` 允许转发的目标 URL（仅 https + 白名单域名）
  static bool isAllowedProxyTarget(Uri uri) {
    if (uri.scheme != 'https') return false;
    if (uri.userInfo.isNotEmpty) return false;
    if (uri.host.isEmpty) return false;
    // 拒绝 IP 字面量
    if (RegExp(r'^\d{1,3}(\.\d{1,3}){3}$').hasMatch(uri.host)) return false;
    if (uri.host.contains(':')) return false;
    // 仅标准 HTTPS 端口（或未指定端口）
    if (uri.hasPort && uri.port != 443) return false;

    final rule = match(uri.host);
    return rule?.type == ResourceType.authImage ||
        rule?.type == ResourceType.publicAsset;
  }

  /// img-proxy 允许的 HTTPS 图片 URL（白名单 + 论坛常见外链图床）
  static bool isAllowedImgProxyTarget(Uri uri) {
    if (isAllowedProxyTarget(uri)) return true;

    if (uri.scheme != 'https') return false;
    if (uri.userInfo.isNotEmpty) return false;
    if (uri.host.isEmpty) return false;
    if (RegExp(r'^\d{1,3}(\.\d{1,3}){3}$').hasMatch(uri.host)) return false;
    if (uri.host == 'localhost' || uri.host.endsWith('.localhost')) {
      return false;
    }
    if (uri.hasPort && uri.port != 443) return false;

    return true;
  }

  /// 外链图床（回复插图），Web 经代理 `/ext-upload` 转发。
  static const String externalImageHost = 'p.sda1.dev';
  static const String externalImageUploadPath =
      '/api/v1/upload_external_noform';

  static String get externalImageUploadUrl =>
      'https://$externalImageHost$externalImageUploadPath';
}
