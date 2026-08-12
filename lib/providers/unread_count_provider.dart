import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/notice_item.dart';
import '../models/unread_count.dart';

class UnreadCountNotifier extends Notifier<UnreadCount> {
  /// Session-only pending mypost notice ids (cleared on logout / process death).
  final Set<String> _pendingMypostIds = {};

  /// True after at least one mypost list merge, or HTML-only tap fallback.
  bool _mypostListSeeded = false;

  int _serverNewpm = 0;
  int _serverNewprompt = 0;
  int _serverNewmypost = 0;

  /// Previous server [newmypost] for rising-edge (0 → N) after local clear.
  int _prevServerNewmypost = 0;

  @override
  UnreadCount build() => UnreadCount.zero;

  void updateFromNotice(Map<String, dynamic> noticeMap) {
    final parsed = UnreadCount.fromJson(noticeMap);
    _prevServerNewmypost = _serverNewmypost;
    _serverNewpm = parsed.newpm;
    _serverNewprompt = parsed.newprompt;
    _serverNewmypost = parsed.newmypost;
    // After local clear, 0→N means new replies: trust server lamp again
    // until the next mypost list merge re-seeds pending ids.
    if (_mypostListSeeded &&
        _pendingMypostIds.isEmpty &&
        _prevServerNewmypost == 0 &&
        _serverNewmypost > 0) {
      _mypostListSeeded = false;
    }
    _publish();
  }

  /// Merge `isNew` mypost notice ids. Never drops untapped ids on refresh.
  /// Pages with no `isNew` (HTML fallback) do not set seeded, so the server
  /// lamp stays until tap or a JSON seed.
  void mergeMypostFromList(List<NoticeItem> items) {
    var sawNew = false;
    for (final item in items) {
      if (!item.isNew) continue;
      final id = item.id.trim();
      if (id.isEmpty) continue;
      sawNew = true;
      _pendingMypostIds.add(id);
    }
    if (!sawNew) return;
    _mypostListSeeded = true;
    _publish();
  }

  /// Mark one notice as read (tap into thread). HTML-only: first tap seeds
  /// and clears the server mypost lamp when pending was never populated.
  void markMypostRead(String id) {
    final trimmed = id.trim();
    var changed = false;

    if (trimmed.isNotEmpty && _pendingMypostIds.remove(trimmed)) {
      changed = true;
    }

    if (!_mypostListSeeded) {
      // HTML fallback / never merged isNew: tapping a mypost notice clears
      // the server-driven lamp for this session.
      _mypostListSeeded = true;
      changed = true;
    }

    if (changed) {
      _publish();
    }
  }

  void clear() {
    _pendingMypostIds.clear();
    _mypostListSeeded = false;
    _serverNewpm = 0;
    _serverNewprompt = 0;
    _serverNewmypost = 0;
    _prevServerNewmypost = 0;
    if (state != UnreadCount.zero) {
      state = UnreadCount.zero;
    }
  }

  void debugSetState(UnreadCount count) {
    _serverNewpm = count.newpm;
    _serverNewprompt = count.newprompt;
    _serverNewmypost = count.newmypost;
    _prevServerNewmypost = count.newmypost;
    _pendingMypostIds.clear();
    _mypostListSeeded = false;
    state = count;
  }

  int get _effectiveNewmypost {
    if (_pendingMypostIds.isNotEmpty) {
      return _pendingMypostIds.length;
    }
    if (!_mypostListSeeded) {
      return _serverNewmypost;
    }
    // Seeded and pending empty: suppress stale server newmypost.
    return 0;
  }

  void _publish() {
    final next = UnreadCount(
      newpm: _serverNewpm,
      newprompt: _serverNewprompt,
      newmypost: _effectiveNewmypost,
    );
    if (state != next) {
      state = next;
    }
  }
}

final unreadCountProvider = NotifierProvider<UnreadCountNotifier, UnreadCount>(
  UnreadCountNotifier.new,
);
