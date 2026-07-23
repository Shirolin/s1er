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
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsProvider.overrideWith(
            () => SettingsNotifier(
              initial: AppSettings(postListDensity: density),
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

  testWidgets('standard post density uses larger avatar chrome',
      (tester) async {
    await pumpPost(tester, density: ListDensity.standard);
    final avatar = tester.widget<WebAvatar>(find.byType(WebAvatar));
    final card = tester.widget<Card>(find.byType(Card).first);
    expect(avatar.radius, 20);
    expect(
      card.margin,
      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    );
  });

  testWidgets('compact post density uses smaller avatar chrome',
      (tester) async {
    await pumpPost(tester, density: ListDensity.compact);
    final avatar = tester.widget<WebAvatar>(find.byType(WebAvatar));
    final card = tester.widget<Card>(find.byType(Card).first);
    expect(avatar.radius, 16);
    expect(
      card.margin,
      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    );
  });

  test('PostItemDensityTokens map density modes', () {
    expect(
      PostItemDensityTokens.forDensity(ListDensity.standard).avatarRadius,
      20,
    );
    expect(
      PostItemDensityTokens.forDensity(ListDensity.compact).inlineAuthorMeta,
      isTrue,
    );
    expect(
      PostItemDensityTokens.forDensity(ListDensity.compact).cardPadding,
      8,
    );
  });
}
