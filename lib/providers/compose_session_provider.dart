import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/compose_draft.dart';
import '../models/compose_target.dart';
import '../services/settings_store.dart';
import '../utils/map_draft_codec.dart';
import 'settings_provider.dart';

/// 一次撰写的本地草稿：按 [ComposeTarget] 寻址，存于 `SettingsStore`。
///
/// 回复、新主题、编辑各占一个 settings key，互不读写。回复正文防抖保存，
/// 其余即时保存；尚未落盘的回复草稿在 provider 销毁时补写。
class ComposeSession {
  ComposeSession(this._target, this._store);

  static const _replyDebounce = Duration(milliseconds: 400);

  final ComposeTarget _target;
  final SettingsStore _store;
  Timer? _pendingTimer;
  ComposeDraft? _pendingDraft;

  /// 无草稿、或草稿按本目标规则视为空时返回 null。
  ComposeDraft? restoreDraft() {
    final key = _entryKey;
    if (key == null) return null;
    final payload = _drafts()[key];
    final draft = payload == null ? null : ComposeDraft.fromJson(payload);
    if (draft == null || _isBlank(draft)) return null;
    return draft;
  }

  /// 空草稿（规则同 [restoreDraft]）会删除已存条目。
  void saveDraft(ComposeDraft draft) {
    if (_entryKey == null) return;
    if (_target is ReplyTarget) {
      _pendingDraft = draft;
      _pendingTimer?.cancel();
      _pendingTimer = Timer(_replyDebounce, _flush);
      return;
    }
    _write(draft);
  }

  /// 同时丢弃尚未落盘的保存。
  void clearDraft() {
    _cancelPending();
    final key = _entryKey;
    if (key == null) return;
    _put(MapDraftCodec.remove(_drafts(), key));
  }

  void _flush() {
    final draft = _pendingDraft;
    _cancelPending();
    if (draft != null) _write(draft);
  }

  void _cancelPending() {
    _pendingTimer?.cancel();
    _pendingTimer = null;
    _pendingDraft = null;
  }

  void _write(ComposeDraft draft) {
    _put(
      MapDraftCodec.upsert(
        _drafts(),
        _entryKey!,
        _payload(draft),
        isEmpty: _isBlank(draft),
      ),
    );
  }

  Map<String, Map<String, Object?>> _drafts() =>
      MapDraftCodec.parse(_store.get<Object>(_settingsKey));

  void _put(Map<String, Map<String, Object?>> drafts) =>
      _store.put(_settingsKey, MapDraftCodec.toStoreValue(drafts));

  String get _settingsKey => switch (_target) {
        ReplyTarget() => 'compose_message_drafts',
        NewThreadTarget() => 'new_thread_drafts',
        EditPostTarget() => 'edit_post_drafts',
      };

  String? get _entryKey {
    final key = switch (_target) {
      ReplyTarget(:final tid, :final reppost) =>
        tid.isEmpty || (reppost?.trim() ?? '').isEmpty
            ? tid
            : '$tid:${reppost!.trim()}',
      NewThreadTarget(:final fid) => fid,
      EditPostTarget(:final pid) => pid,
    };
    return key.isEmpty ? null : key;
  }

  bool _isBlank(ComposeDraft draft) => switch (_target) {
        ReplyTarget() => draft.message.trim().isEmpty,
        NewThreadTarget() =>
          draft.subject.trim().isEmpty && draft.message.trim().isEmpty,
        // 正文暂空也保存，以便恢复标题、分类等其余字段。
        EditPostTarget() => false,
      };

  Map<String, Object?> _payload(ComposeDraft draft) => switch (_target) {
        ReplyTarget() => {
            'message': draft.message,
            'updatedAt': _now(),
          },
        NewThreadTarget() => {
            'subject': draft.subject,
            'message': draft.message,
            if (draft.typeId != null) 'typeId': draft.typeId,
          },
        EditPostTarget() => {
            'subject': draft.subject,
            'message': draft.message,
            if (draft.typeId != null) 'typeId': draft.typeId,
            if (draft.readPerm != null) 'readPerm': draft.readPerm,
            if (draft.leadingQuote != null) 'leadingQuote': draft.leadingQuote,
            if (draft.includeQuote != null) 'includeQuote': draft.includeQuote,
            if (draft.mediaTags != null) 'mediaTags': draft.mediaTags,
            if (draft.mediaSlots != null) 'mediaSlots': draft.mediaSlots,
            'updatedAt': _now(),
          },
      };

  static String _now() => DateTime.now().toUtc().toIso8601String();
}

final composeSessionProvider =
    Provider.autoDispose.family<ComposeSession, ComposeTarget>((ref, target) {
  final session = ComposeSession(target, ref.watch(settingsStoreProvider));
  ref.onDispose(session._flush);
  return session;
});
