import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:s1_app/models/rate_form.dart';
import 'package:s1_app/providers/api_service_provider.dart';
import 'package:s1_app/services/api_service.dart';
import 'package:s1_app/services/http_client.dart';
import 'package:s1_app/theme/app_theme.dart';
import 'package:s1_app/widgets/rate_dialog.dart';

class _FakeApiService extends ApiService {
  _FakeApiService({
    required RateFormOptions rateForm,
    List<RateFormOptions>? rateForms,
  })  : _rateForms = rateForms ?? [rateForm],
        super(S1HttpClient.test(ProviderContainer(), Dio()));

  final List<RateFormOptions> _rateForms;
  int _fetchCount = 0;

  @override
  Future<RateFormOptions> fetchRateForm({
    required String tid,
    required String pid,
  }) async {
    final index = _fetchCount.clamp(0, _rateForms.length - 1);
    _fetchCount++;
    return _rateForms[index];
  }
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
  testWidgets('RateDialog shows score chips with default +1 selection',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          apiServiceProvider.overrideWithValue(
            _FakeApiService(
              rateForm: const RateFormOptions(
                scoreOptions: RateFormOptions.defaultScoreOptions,
                reasonPresets: RateFormOptions.defaultReasonPresets,
                totalScore: 5,
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
    expect(find.text('当前总战斗力：+5'), findsOneWidget);
    expect(find.text('+2'), findsOneWidget);
    expect(find.text('0'), findsNothing);

    for (final score in ['+2', '+1', '-1', '-2']) {
      final chip =
          tester.widget<FilterChip>(find.widgetWithText(FilterChip, score));
      expect(chip.selected, score == '+1');
    }
  });

  testWidgets('RateDialog shows retry action for retryable fetch error',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          apiServiceProvider.overrideWithValue(
            _FakeApiService(
              rateForm: RateFormOptions.withDefaults(
                error: '网络错误',
                retryable: true,
              ),
              rateForms: [
                RateFormOptions.withDefaults(
                  error: '网络错误',
                  retryable: true,
                ),
                const RateFormOptions(
                  scoreOptions: RateFormOptions.defaultScoreOptions,
                  reasonPresets: RateFormOptions.defaultReasonPresets,
                ),
              ],
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

    expect(find.text('网络错误'), findsOneWidget);
    expect(find.text('重试'), findsOneWidget);
    expect(find.text('评分'), findsOneWidget);

    await tester.tap(find.text('重试'));
    await tester.pumpAndSettle();

    expect(find.text('+1'), findsOneWidget);
    expect(find.text('评分'), findsOneWidget);
  });

  testWidgets('RateDialog keeps business error in dialog', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          apiServiceProvider.overrideWithValue(
            _FakeApiService(
              rateForm: RateFormOptions.withDefaults(error: '不能给自己评分'),
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

    expect(find.text('不能给自己评分'), findsOneWidget);
    expect(find.text('关闭'), findsOneWidget);
    expect(find.text('重试'), findsNothing);
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

  testWidgets('RateDialog applies notify author default and disabled state',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          apiServiceProvider.overrideWithValue(
            _FakeApiService(
              rateForm: const RateFormOptions(
                scoreOptions: RateFormOptions.defaultScoreOptions,
                reasonPresets: RateFormOptions.defaultReasonPresets,
                notifyAuthorDefault: true,
                notifyAuthorDisabled: true,
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

    final tile = tester.widget<CheckboxListTile>(find.byType(CheckboxListTile));
    expect(tile.value, isTrue);
    expect(tile.onChanged, isNull);
  });
}
