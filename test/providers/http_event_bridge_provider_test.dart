import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:s1er/providers/http_event_bridge_provider.dart';
import 'package:s1er/providers/server_notice_provider.dart';
import 'package:s1er/providers/unread_count_provider.dart';
import 'package:s1er/services/http_client.dart';
import 'package:s1er/services/s1_http_event.dart';

/// 覆盖 ADR-0004 的接缝：客户端只发事件，provider 层适配器落库。
ProviderContainer _containerWith(S1HttpClient client) {
  final container = ProviderContainer(
    overrides: [httpClientProvider.overrideWithValue(client)],
  );
  return container;
}

void main() {
  test('bridge forwards unread notice event to unreadCountProvider', () async {
    final client = S1HttpClient.test(ProviderContainer(), Dio());
    final container = _containerWith(client);
    addTearDown(container.dispose);
    addTearDown(client.dispose);
    container.read(httpEventBridgeProvider);

    client.debugEmit(
      const S1UnreadNoticeEvent({'newpm': '3', 'newprompt': '1'}),
    );
    await Future<void>.delayed(Duration.zero);

    final unread = container.read(unreadCountProvider);
    expect(unread.newpm, 3);
    expect(unread.newprompt, 1);
  });

  test('bridge forwards server notice event to serverNoticeProvider', () async {
    final client = S1HttpClient.test(ProviderContainer(), Dio());
    final container = _containerWith(client);
    addTearDown(container.dispose);
    addTearDown(client.dispose);
    container.read(httpEventBridgeProvider);

    client.debugEmit(const S1ServerNoticeEvent('服务器维护中'));
    await Future<void>.delayed(Duration.zero);

    expect(container.read(serverNoticeProvider), '服务器维护中');
  });

  test('bridge stops forwarding after container disposal', () async {
    final client = S1HttpClient.test(ProviderContainer(), Dio());
    final container = _containerWith(client);
    addTearDown(client.dispose);
    container.read(httpEventBridgeProvider);

    container.dispose();
    // 容器销毁后订阅已取消；补发不应抛错。
    client.debugEmit(const S1ServerNoticeEvent('after-dispose'));
    await Future<void>.delayed(Duration.zero);
  });
}
