import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:s1er/utils/bbcode_parser.dart';
import 'package:s1er/utils/post_image_index_counter.dart';
import 'package:s1er/widgets/bbcode_renderer.dart';

void main() {
  testWidgets('BbcodeRenderer renders moyu post with spaces without ReDoS lag',
      (tester) async {
    const moyuMessage = '''
&nbsp;            &nbsp;X&nbsp;     &nbsp; Business_Report_2025.xlsx - Excel&nbsp;    &nbsp;<br />
&nbsp;         &nbsp; 文件&nbsp;     &nbsp; 开始&nbsp;     &nbsp; 插入&nbsp;     &nbsp; 页面布局&nbsp;     &nbsp; 公式&nbsp;     &nbsp; 数据&nbsp;     &nbsp; 审阅&nbsp;     &nbsp; 视图&nbsp;    &nbsp;<br />
&nbsp;                &nbsp;📋 粘贴<br />
&nbsp;     &nbsp; <br />
&nbsp;     &nbsp; <br />
&nbsp;                         &nbsp; <strong>B</strong> I U<br />
&nbsp;     &nbsp; <br />
&nbsp;     &nbsp; <br />
&nbsp;     &nbsp; <font color="#999">&nbsp;      自动换行&nbsp;      合并后居中&nbsp;     &nbsp; </font><br />
&nbsp;    &nbsp;<br />
&nbsp;         &nbsp; A1&nbsp;     &nbsp; fx&nbsp;     &nbsp; <br />
&nbsp;    &nbsp;<br />
&nbsp;         &nbsp; &nbsp;     &nbsp; A&nbsp;     &nbsp; B&nbsp;     &nbsp; C&nbsp;     &nbsp; D&nbsp;     &nbsp; E&nbsp;     &nbsp; F&nbsp;    &nbsp;<br />
&nbsp;         &nbsp; 1&nbsp;     &nbsp; 项目名称&nbsp;     &nbsp; 季度预算&nbsp;     &nbsp; 实际支出&nbsp;     &nbsp; 完成进度&nbsp;     &nbsp; 负责人&nbsp;     &nbsp; 状态&nbsp;    &nbsp;<br />
&nbsp;         &nbsp; 2&nbsp;     &nbsp; 架构重构&nbsp;     &nbsp; ¥150,000&nbsp;     &nbsp; ¥142,500&nbsp;     &nbsp; 95%&nbsp;     &nbsp; 张伟&nbsp;     &nbsp; 进行中&nbsp;    &nbsp;<br />
&nbsp;         &nbsp; 3&nbsp;     &nbsp; 性能优化&nbsp;     &nbsp; ¥80,000&nbsp;     &nbsp; ¥80,000&nbsp;     &nbsp; 100%&nbsp;     &nbsp; 李娜&nbsp;     &nbsp; 已完成&nbsp;    &nbsp;<br />
''';

    final stopwatch = Stopwatch()..start();
    BbcodeParser.parse(moyuMessage);
    stopwatch.stop();
    expect(
      stopwatch.elapsedMilliseconds,
      lessThan(500),
      reason: 'BbcodeParser parsing should be fast',
    );

    final stopwatchRender = Stopwatch()..start();
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: BbcodeRenderer(
              bbcode: moyuMessage,
              imageIndexCounter: PostImageIndexCounter(),
              selectable: false,
            ),
          ),
        ),
      ),
    );
    stopwatchRender.stop();
    expect(
      stopwatchRender.elapsedMilliseconds,
      lessThan(1000),
      reason:
          'BbcodeRenderer pump should take under 1s (was 17.5s before ReDoS fix)',
    );
  });
}
