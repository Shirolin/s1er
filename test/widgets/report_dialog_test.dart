import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:s1_app/models/report_form.dart';
import 'package:s1_app/providers/api_service_provider.dart';
import 'package:s1_app/services/api_service.dart';
import 'package:s1_app/services/http_client.dart';
import 'package:s1_app/theme/app_theme.dart';
import 'package:s1_app/widgets/report_dialog.dart';

class _FakeApiService extends ApiService {
  _FakeApiService({this.submitError})
      : super(S1HttpClient.test(ProviderContainer(), Dio()));

  final String? submitError;
  int fetchCount = 0;
  int submitCount = 0;

  @override
  Future<ReportFormOptions> fetchReportForm({
    required String tid,
    required String pid,
    String? fid,
    int page = 1,
  }) async {
    fetchCount++;
    return const ReportFormOptions(
      reasons: ReportFormOptions.defaultReasons,
      fields: {'formhash': 'hash', 'rid': '2'},
    );
  }

  @override
  Future<String?> submitReport({
    required String tid,
    required String pid,
    String? fid,
    required String reason,
    required String message,
    required ReportFormOptions form,
  }) async {
    submitCount++;
    return submitError;
  }
}

class _OpenReport extends ConsumerWidget {
  const _OpenReport();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return TextButton(
      onPressed: () => showReportDialog(
        context,
        ref,
        tid: '1',
        pid: '2',
      ),
      child: const Text('open'),
    );
  }
}

Widget _app(_FakeApiService service) {
  return ProviderScope(
    overrides: [apiServiceProvider.overrideWithValue(service)],
    child: MaterialApp(
      theme: AppTheme.lightTheme('purple'),
      home: const Scaffold(body: _OpenReport()),
    ),
  );
}

void main() {
  testWidgets('ReportDialog loads reasons and validates required message',
      (tester) async {
    final service = _FakeApiService();
    await tester.pumpWidget(_app(service));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('举报'), findsOneWidget);
    expect(find.text('广告垃圾'), findsOneWidget);
    await tester.tap(find.text('提交举报'));
    await tester.pumpAndSettle();
    expect(find.text('请填写具体说明'), findsOneWidget);
    expect(service.submitCount, 0);
  });

  testWidgets('ReportDialog submits and closes on success', (tester) async {
    final service = _FakeApiService();
    await tester.pumpWidget(_app(service));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), '违规内容说明');
    await tester.tap(find.text('提交举报'));
    await tester.pumpAndSettle();

    expect(service.submitCount, 1);
    expect(find.text('举报'), findsNothing);
  });

  testWidgets('ReportDialog keeps open on submit error', (tester) async {
    final service = _FakeApiService(submitError: '已举报');
    await tester.pumpWidget(_app(service));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), '重复提交测试');
    await tester.tap(find.text('提交举报'));
    await tester.pumpAndSettle();

    expect(find.text('举报'), findsOneWidget);
    expect(find.text('重复提交测试'), findsOneWidget);
  });
}
