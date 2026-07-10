import 'package:cookie_jar/cookie_jar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../config/api_config.dart';
import '../config/resource_domains.dart';
import '../providers/auth_provider.dart';

/// 原生平台 WebView 登录：密码仅在 WebView 内输入，不经过 Flutter 代码。
class LoginWebViewScreen extends ConsumerStatefulWidget {
  const LoginWebViewScreen({super.key});

  @override
  ConsumerState<LoginWebViewScreen> createState() => _LoginWebViewScreenState();
}

class _LoginWebViewScreenState extends ConsumerState<LoginWebViewScreen> {
  late final WebViewController _controller;
  final _cookieManager = WebViewCookieManager();
  bool _isLoading = true;
  bool _isCompleting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) => _setLoading(true),
          onPageFinished: (_) {
            _setLoading(false);
            _tryCompleteLogin();
          },
          onWebResourceError: (error) {
            _setLoading(false);
            setState(() {
              _errorMessage = '页面加载失败: ${error.description}';
            });
          },
        ),
      )
      ..loadRequest(Uri.parse(ApiConfig.loginUrl));
  }

  void _setLoading(bool loading) {
    if (!mounted) return;
    setState(() => _isLoading = loading);
  }

  Future<void> _tryCompleteLogin() async {
    if (_isCompleting) return;

    final cookies = await _cookieManager.getCookies(
      domain: Uri.parse('https://${ResourceDomains.apiHost}'),
    );
    final hasAuth = cookies.any(
      (c) =>
          c.name.startsWith(ResourceDomains.cookiePrefix) &&
          c.name.endsWith('auth') &&
          c.value.isNotEmpty,
    );
    if (!hasAuth) return;

    _isCompleting = true;
    setState(() {
      _errorMessage = null;
      _isLoading = true;
    });

    final authService = ref.read(authServiceProvider);
    final jarCookies = cookies
        .map(
          (c) => Cookie(c.name, c.value)
            ..domain = c.domain
            ..path = c.path,
        )
        .toList();
    await authService.importWebViewCookies(jarCookies);

    final error = await ref.read(authStateProvider.notifier).completeWebViewLogin();
    if (!mounted) return;

    if (error == null) {
      context.go('/');
    } else {
      setState(() {
        _isCompleting = false;
        _isLoading = false;
        _errorMessage = error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('登录 Stage1st'),
      ),
      body: Column(
        children: [
          if (_errorMessage != null)
            MaterialBanner(
              content: Text(_errorMessage!),
              backgroundColor: scheme.errorContainer,
              leading: Icon(Icons.error_outline, color: scheme.onErrorContainer),
              actions: [
                TextButton(
                  onPressed: () => setState(() => _errorMessage = null),
                  child: const Text('关闭'),
                ),
              ],
            ),
          if (_isLoading)
            const LinearProgressIndicator(minHeight: 2),
          Expanded(child: WebViewWidget(controller: _controller)),
        ],
      ),
    );
  }
}
