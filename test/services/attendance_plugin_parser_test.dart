import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:s1er/models/attendance_result.dart';
import 'package:s1er/services/attendance_plugin_parser.dart';
import 'package:s1er/services/forum_tools_service.dart';

/// 用 2026-10-27 抓到的真实页面做夹具：
/// - ready：未签到，`div.muanyun-053-actions` 里有 `op=checkin` 表单；
/// - signed：已签到，同一位置只剩 disabled 按钮；
/// - success：`op=checkin` 提交后的结果页。
void main() {
  String fixture(String name) => File('test/fixtures/$name').readAsStringSync();

  group('AttendancePluginPage', () {
    test('未签到页面存在 checkin 表单', () {
      final page = AttendancePluginPage.parse(
        fixture('muanyun_sign_page_ready.html'),
      );
      expect(page.signedToday, isFalse);
      expect(page.unavailable, isFalse);
      expect(page.formhash, isNotNull);
    });

    test('已签到页面没有 checkin 表单', () {
      final page = AttendancePluginPage.parse(
        fixture('muanyun_sign_page_signed.html'),
      );
      expect(page.signedToday, isTrue);
      expect(page.unavailable, isFalse);
    });

    test('已签到页面能解析累计与连续签到', () {
      final page = AttendancePluginPage.parse(
        fixture('muanyun_sign_page_signed.html'),
      );
      expect(page.totalDays, 2);
      expect(page.consecutiveDays, 2);
    });

    test('插件下线文案识别为 unavailable', () {
      final page = AttendancePluginPage.parse(
        '<div class="tip"><p>插件不存在或已关闭</p></div>',
      );
      expect(page.unavailable, isTrue);
    });

    test('空响应不崩', () {
      final page = AttendancePluginPage.parse('');
      expect(page.signedToday, isFalse);
      expect(page.formhash, isNull);
    });
  });

  group('AttendanceCheckinOutcome', () {
    test('结果页解析成功与连续天数', () {
      final outcome = AttendanceCheckinOutcome.parse(
        fixture('muanyun_checkin_success.html'),
      );
      expect(outcome.signed, isTrue);
      expect(outcome.consecutiveDays, 2);
      expect(outcome.message, contains('签到成功'));
      // 不应把内联样式塞进用户文案。
      expect(outcome.message, isNot(contains('<span')));
      expect(outcome.message, isNot(contains('color:')));
    });

    test('结果文案保留服务端分行，不在「连续签到 N 天」中间折断', () {
      final outcome = AttendanceCheckinOutcome.parse(
        fixture('muanyun_checkin_success.html'),
      );
      // 插件用 <br/> 把「奖励 / 倍数说明 / 连续签到」分成三段；倍数说明在
      // span 内，剥离后留下的空段应丢弃，而不是留一行空白。
      expect(outcome.message.split('\n'), [
        '签到成功！获得经验 10 点、死鱼 1 点',
        '连续签到 2 天',
      ]);
    });
  });

  group('ForumToolsService.parseAttendancePage', () {
    test('未签到返回 ready', () {
      final result = ForumToolsService.parseAttendancePage(
        fixture('muanyun_sign_page_ready.html'),
      );
      expect(result.outcome, AttendanceOutcome.ready);
      expect(result.isSignedToday, isFalse);
    });

    test('已签到返回 alreadySigned 并带统计', () {
      final result = ForumToolsService.parseAttendancePage(
        fixture('muanyun_sign_page_signed.html'),
      );
      expect(result.outcome, AttendanceOutcome.alreadySigned);
      expect(result.message, contains('累计 2 天'));
    });

    test('插件下线返回 unavailable', () {
      final result = ForumToolsService.parseAttendancePage(
        '<div class="tip">插件不存在或已关闭</div>',
      );
      expect(result.outcome, AttendanceOutcome.unavailable);
    });
  });

  group('ForumToolsService.parseAttendanceResponse', () {
    test('签到成功结果页解析为 signedNow', () {
      final result = ForumToolsService.parseAttendanceResponse(
        fixture('muanyun_checkin_success.html'),
      );
      expect(result.outcome, AttendanceOutcome.signedNow);
      expect(result.isSignedToday, isTrue);
    });

    test('提交后仍是未签到页面则判定失败', () {
      final result = ForumToolsService.parseAttendanceResponse(
        fixture('muanyun_sign_page_ready.html'),
      );
      expect(result.outcome, AttendanceOutcome.failed);
    });

    test('插件下线返回 unavailable', () {
      final result = ForumToolsService.parseAttendanceResponse(
        '<div class="tip">插件不存在或已关闭</div>',
      );
      expect(result.outcome, AttendanceOutcome.unavailable);
    });
  });
}
