import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:s1er/models/compose_draft.dart';
import 'package:s1er/models/compose_target.dart';
import 'package:s1er/providers/compose_session_provider.dart';
import 'package:s1er/providers/settings_provider.dart';
import 'package:s1er/services/app_database.dart';
import 'package:s1er/services/app_local_data.dart';

import '../helpers/test_local_data.dart';

void main() {
  late AppDatabase db;
  late AppLocalData local;
  late ProviderContainer container;

  setUp(() async {
    final opened = await openTestLocalData();
    db = opened.$1;
    local = opened.$2;
    container = ProviderContainer(
      overrides: [localDataProvider.overrideWithValue(local)],
    );
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  ProviderSubscription<ComposeSession> open(ComposeTarget target) =>
      container.listen(composeSessionProvider(target), (_, __) {});

  Object? stored(String key) => local.settings.get<Object>(key);

  test('targets keep drafts in separate settings keys', () {
    open(const NewThreadTarget(fid: '4'))
        .read()
        .saveDraft(const ComposeDraft(subject: '标题', message: '新帖'));
    open(const EditPostTarget(pid: '200'))
        .read()
        .saveDraft(const ComposeDraft(message: '编辑'));

    expect(open(const ReplyTarget(tid: '100')).read().restoreDraft(), isNull);
    expect(
      (stored('new_thread_drafts') as Map)['4'],
      {'subject': '标题', 'message': '新帖'},
    );
    expect(
      ((stored('edit_post_drafts') as Map)['200'] as Map)['message'],
      '编辑',
    );
  });

  Future<void> waitDebounce() =>
      Future<void>.delayed(const Duration(milliseconds: 450));

  test('reply saves after debounce under tid:reppost key', () async {
    final session = open(const ReplyTarget(tid: '100', reppost: ' 42 ')).read();
    session.saveDraft(const ComposeDraft(message: '回复'));
    expect(stored('compose_message_drafts'), isNull);

    await waitDebounce();
    expect(
      ((stored('compose_message_drafts') as Map)['100:42'] as Map)['message'],
      '回复',
    );
    expect(session.restoreDraft()?.message, '回复');
  });

  test('pending reply save is written when the session is disposed', () async {
    final subscription = open(const ReplyTarget(tid: '100'));
    subscription.read().saveDraft(const ComposeDraft(message: '未落盘'));
    subscription.close();
    await container.pump();

    expect(
      ((stored('compose_message_drafts') as Map)['100'] as Map)['message'],
      '未落盘',
    );
  });

  test('clearDraft drops the stored and the pending reply draft', () async {
    final subscription = open(const ReplyTarget(tid: '100'));
    final session = subscription.read();
    session.saveDraft(const ComposeDraft(message: '旧'));
    await waitDebounce();
    session.saveDraft(const ComposeDraft(message: '新'));
    session.clearDraft();
    subscription.close();
    await container.pump();

    expect(stored('compose_message_drafts'), isNull);
  });

  test('blank reply and new-thread drafts are removed, edit drafts kept', () {
    final newThread = open(const NewThreadTarget(fid: '4')).read();
    newThread.saveDraft(const ComposeDraft(subject: 't', message: 'm'));
    newThread.saveDraft(const ComposeDraft(subject: ' ', message: ''));
    expect(stored('new_thread_drafts'), isNull);

    final edit = open(const EditPostTarget(pid: '200')).read();
    edit.saveDraft(const ComposeDraft(subject: '保留标题', message: ''));
    expect(edit.restoreDraft()?.subject, '保留标题');
  });

  test('legacy drafts without optional fields still restore', () {
    local.settings.put('compose_message_drafts', {
      '100': {'message': '旧回复', 'updatedAt': '2026-07-14T00:00:00.000Z'},
    });
    local.settings.put('new_thread_drafts', {
      '4': {'subject': '旧标题', 'message': '旧新帖'},
    });
    local.settings.put('edit_post_drafts', {
      '200': {
        'message': '旧编辑⟦图1⟧',
        'mediaSlots': ['1'],
      },
    });

    final reply = open(const ReplyTarget(tid: '100')).read().restoreDraft()!;
    expect(reply.message, '旧回复');
    expect(reply.subject, '');
    expect(reply.typeId, isNull);
    expect(reply.mediaTags, isNull);

    final newThread =
        open(const NewThreadTarget(fid: '4')).read().restoreDraft()!;
    expect(newThread.message, '旧新帖');
    expect(newThread.subject, '旧标题');
    expect(newThread.typeId, isNull);

    final edit = open(const EditPostTarget(pid: '200')).read().restoreDraft()!;
    expect(edit.message, '旧编辑⟦图1⟧');
    expect(edit.subject, '');
    expect(edit.readPerm, isNull);
    expect(edit.leadingQuote, isNull);
    expect(edit.includeQuote, isNull);
    expect(edit.mediaTags, isNull);
    expect(edit.mediaSlots, [1], reason: '字符串 slot 回退为 int');
  });

  test('malformed draft payloads restore as null', () {
    local.settings.put('compose_message_drafts', {
      '100': 'not-a-map',
      '101': <String, Object?>{'updatedAt': '2026-07-14T00:00:00.000Z'},
      '102': <String, Object?>{'message': 42},
    });

    final reply = open(const ReplyTarget(tid: '100')).read();
    expect(reply.restoreDraft(), isNull);
    expect(open(const ReplyTarget(tid: '101')).read().restoreDraft(), isNull);
    expect(open(const ReplyTarget(tid: '102')).read().restoreDraft(), isNull);
  });

  test('edit draft round-trips media slots and quote state', () {
    final edit = open(const EditPostTarget(pid: '200')).read();
    edit.saveDraft(
      const ComposeDraft(
        message: '文⟦图2⟧本',
        typeId: '1',
        readPerm: '0',
        leadingQuote: '[quote]引[/quote]',
        includeQuote: false,
        mediaTags: [
          '[img]https://a.test/1.png[/img]',
          '[img]https://a.test/2.png[/img]',
        ],
        mediaSlots: [1, 2],
      ),
    );

    final restored = edit.restoreDraft()!;
    expect(restored.message, '文⟦图2⟧本');
    expect(restored.typeId, '1');
    expect(restored.readPerm, '0');
    expect(restored.leadingQuote, '[quote]引[/quote]');
    expect(restored.includeQuote, isFalse);
    expect(restored.mediaTags, hasLength(2));
    expect(restored.mediaSlots, [1, 2]);
  });
}
