import 'package:flutter_test/flutter_test.dart';
import 'package:s1er/utils/edit_post_draft.dart';

void main() {
  test('edit draft stores editable fields without source baseline', () {
    final drafts = EditPostDraftStore.upsert(
      {},
      '200',
      subject: '新标题',
      message: '新正文',
      typeId: '1',
      readPerm: '0',
    );
    final parsed = EditPostDraftStore.parse(
      EditPostDraftStore.toStoreValue(drafts),
    );
    expect(parsed['200']?['message'], '新正文');
    expect(parsed['200']?.containsKey('sourceMessage'), isFalse);
  });

  test('edit draft stores mediaTags with parallel mediaSlots', () {
    final drafts = EditPostDraftStore.upsert(
      {},
      '200',
      subject: '',
      message: '文⟦图2⟧本',
      mediaTags: const [
        '[img]https://a.test/1.png[/img]',
        '[img]https://a.test/2.png[/img]',
      ],
      mediaSlots: const [1, 2],
    );
    final entry = drafts['200']!;
    expect(entry['mediaTags'], hasLength(2));
    expect(entry['mediaSlots'], [1, 2]);
  });
}
