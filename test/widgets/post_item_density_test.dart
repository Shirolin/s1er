import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:s1er/models/list_density.dart';
import 'package:s1er/models/post.dart';
import 'package:s1er/providers/settings_provider.dart';
import 'package:s1er/widgets/post_item.dart';
import 'package:s1er/widgets/web_avatar.dart';

import '../helpers/test_theme.dart';

void main() {
  final samplePost = Post(
    pid: '1',
    message: '短正文',
    author: '作者名',
    authorId: '10',
    dateline: 1700000000,
    floor: 3,
  );

  Future<void> pumpPost(
    WidgetTester tester, {
    required ListDensity density,
    bool compactListFullBleed = false,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsProvider.overrideWith(
            () => SettingsNotifier(
              initial: AppSettings(
                postListDensity: density,
                compactListFullBleed: compactListFullBleed,
              ),
            ),
          ),
        ],
        child: wrapWithAppTheme(
          SizedBox(
            width: 400,
            child: PostItem(post: samplePost),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('standard post density matches 32dp avatar chrome',
      (tester) async {
    await pumpPost(tester, density: ListDensity.standard);
    final avatar = tester.widget<WebAvatar>(find.byType(WebAvatar));
    final card = tester.widget<Card>(find.byType(Card).first);
    expect(avatar.radius, 16);
    expect(
      card.margin,
      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    );
    final menuButton = tester.widget<IconButton>(find.byType(IconButton));
    expect(
      menuButton.style?.minimumSize?.resolve(const <WidgetState>{}),
      const Size(32, 32),
    );
  });

  testWidgets('compact post density uses tighter padding than standard',
      (tester) async {
    await pumpPost(tester, density: ListDensity.compact);
    final avatar = tester.widget<WebAvatar>(find.byType(WebAvatar));
    final card = tester.widget<Card>(find.byType(Card).first);
    expect(avatar.radius, 16);
    expect(
      card.margin,
      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    );
    final menuButton = tester.widget<IconButton>(find.byType(IconButton));
    expect(menuButton.style?.tapTargetSize, MaterialTapTargetSize.shrinkWrap);
    expect(
      menuButton.style?.minimumSize?.resolve(const <WidgetState>{}),
      const Size(32, 32),
    );
  });

  test('PostItemDensityTokens map density modes', () {
    expect(
      PostItemDensityTokens.forDensity(ListDensity.standard).avatarRadius,
      16,
    );
    expect(
      PostItemDensityTokens.forDensity(ListDensity.standard).headerActionExtent,
      32,
    );
    expect(
      PostItemDensityTokens.forDensity(ListDensity.compact).inlineAuthorMeta,
      isTrue,
    );
    expect(
      PostItemDensityTokens.forDensity(ListDensity.compact).cardPadding,
      6,
    );
    expect(
      PostItemDensityTokens.forDensity(ListDensity.compact).cardPaddingTop,
      4,
    );
    expect(
      PostItemDensityTokens.forDensity(ListDensity.compact).dividerHeight,
      8,
    );
    expect(
      PostItemDensityTokens.forDensity(ListDensity.compact).headerActionExtent,
      32,
    );
  });

  testWidgets('compact full-bleed drops post card side margin and radius',
      (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await pumpPost(
      tester,
      density: ListDensity.standard,
      compactListFullBleed: true,
    );
    final card = tester.widget<Card>(find.byType(Card).first);
    expect(card.margin, const EdgeInsets.symmetric(vertical: 4));
    final shape = card.shape as RoundedRectangleBorder;
    expect(shape.borderRadius, BorderRadius.zero);
  });
}
