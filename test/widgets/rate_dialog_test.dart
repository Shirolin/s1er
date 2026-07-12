import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:s1_app/models/rate_form.dart';
import 'package:s1_app/providers/post_provider.dart';
import 'package:s1_app/services/api_service.dart';
import 'package:s1_app/services/http_client.dart';
import 'package:s1_app/theme/app_theme.dart';
import 'package:s1_app/widgets/rate_dialog.dart';

class _FakeApiService extends ApiService {
  _FakeApiService({required this.rateForm})
      : super(S1HttpClient.test(ProviderContainer(), Dio()));

  final RateFormOptions rateForm;

  @override
  Future<RateFormOptions> fetchRateForm({
    required String tid,
    required String pid,
  }) async =>
      rateForm;
}

class _RateDialogOpener extends ConsumerWidget {
  const _RateDialogOpener();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return TextButton(
      onPressed: () => showRateDialog(context, ref, tid: '1', pid: '2'),
      child: const Text('open'),
    );
  }
}

void main() {
  testWidgets('RateDialog shows score chips without default selection', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          apiServiceProvider.overrideWithValue(
            _FakeApiService(
              rateForm: const RateFormOptions(
                scoreOptions: RateFormOptions.defaultScoreOptions,
                reasonPresets: RateFormOptions.defaultReasonPresets,
              ),
            ),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme('purple'),
          home: const Scaffold(body: _RateDialogOpener()),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('评分'), findsOneWidget);
    expect(find.text('战斗力'), findsOneWidget);
    expect(find.text('+2'), findsOneWidget);
    expect(find.text('0'), findsNothing);

    for (final score in ['+2', '+1', '-1', '-2']) {
      final chip = tester.widget<FilterChip>(find.widgetWithText(FilterChip, score));
      expect(chip.selected, isFalse);
    }
  });

  testWidgets('RateDialog requires score before submit', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          apiServiceProvider.overrideWithValue(
            _FakeApiService(
              rateForm: const RateFormOptions(
                scoreOptions: RateFormOptions.defaultScoreOptions,
                reasonPresets: RateFormOptions.defaultReasonPresets,
              ),
            ),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme('purple'),
          home: const Scaffold(body: _RateDialogOpener()),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();

    expect(find.text('请选择评分分值'), findsOneWidget);
    expect(find.text('评分'), findsOneWidget);
  });

  testWidgets('RateDialog fills reason from preset chip', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          apiServiceProvider.overrideWithValue(
            _FakeApiService(
              rateForm: const RateFormOptions(
                scoreOptions: RateFormOptions.defaultScoreOptions,
                reasonPresets: RateFormOptions.defaultReasonPresets,
              ),
            ),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme('purple'),
          home: const Scaffold(body: _RateDialogOpener()),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('好评加鹅'));
    await tester.pumpAndSettle();

    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.controller?.text, '好评加鹅');
  });
}
