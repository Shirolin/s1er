import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:s1er/theme/app_theme.dart';
import 'package:s1er/widgets/s1_list_boundary_footer.dart';

void main() {
  testWidgets('S1ListBoundaryFooter renders kind labels', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme('purple'),
        home: const Scaffold(
          body: Column(
            children: [
              S1ListBoundaryFooter(kind: S1ListBoundaryKind.pageContinue),
              S1ListBoundaryFooter(kind: S1ListBoundaryKind.lastPage),
              S1ListBoundaryFooter(kind: S1ListBoundaryKind.listEnd),
              S1ListBoundaryFooter(kind: S1ListBoundaryKind.noMore),
            ],
          ),
        ),
      ),
    );

    expect(find.text('本页到底 · 左滑或点下一页'), findsOneWidget);
    expect(find.text('已是末页'), findsOneWidget);
    expect(find.text('已经到底'), findsOneWidget);
    expect(find.text('没有更多了'), findsOneWidget);
  });

  test('pagedBoundaryKind maps pages', () {
    expect(
      pagedBoundaryKind(currentPage: 1, totalPages: 1),
      S1ListBoundaryKind.listEnd,
    );
    expect(
      pagedBoundaryKind(currentPage: 2, totalPages: 5),
      S1ListBoundaryKind.pageContinue,
    );
    expect(
      pagedBoundaryKind(currentPage: 5, totalPages: 5),
      S1ListBoundaryKind.lastPage,
    );
  });
}
