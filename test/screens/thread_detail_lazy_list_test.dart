import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:s1_app/theme/app_theme.dart';
import 'package:s1_app/widgets/s1_fab_layout.dart';
import 'package:s1_app/widgets/s1_swipe_pagination.dart';

/// Tracks how many list items were built (ListView.builder should not build all).
class _BuildCounter {
  int count = 0;

  void reset() => count = 0;
}

final _buildCounter = _BuildCounter();

class _CountedPostCard extends StatelessWidget {
  const _CountedPostCard({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    _buildCounter.count++;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: SizedBox(
        height: 400,
        child: Center(child: Text(label)),
      ),
    );
  }
}

Widget _buildLazyListHarness({required int itemCount}) {
  _buildCounter.reset();
  return MaterialApp(
    theme: AppTheme.lightTheme('purple'),
    home: Scaffold(
      appBar: AppBar(title: const Text('Thread')),
      body: S1SwipePagination(
        currentPage: 1,
        totalPages: 1,
        onPageChanged: (_) async {},
        pageBuilder: (context, scrollController) => Scrollbar(
          controller: scrollController,
          child: ListView.builder(
            controller: scrollController,
            padding: S1FabLayout.scrollBottomPadding,
            itemCount: itemCount,
            itemBuilder: (context, index) => _CountedPostCard(
              label: 'Post ${index + 1}',
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('ListView.builder does not build all items when list is long',
      (tester) async {
    const itemCount = 20;
    await tester.pumpWidget(_buildLazyListHarness(itemCount: itemCount));
    await tester.pumpAndSettle();

    expect(_buildCounter.count, lessThan(itemCount));
    expect(_buildCounter.count, greaterThan(0));
    expect(find.text('Post 1'), findsOneWidget);
  });
}
