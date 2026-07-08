# 阅读历史 + 阅读进度 — 最终实现计划

## 目标

为 S1 客户端添加本地阅读历史记录和阅读进度追踪功能。用户进入帖子时自动记录，再次打开时可续读，帖子列表中显示进度标识。

## 前置约束

- 存储：Hive，不引入新依赖
- 架构：Screen → Provider → Service → Hive，不跨层
- 导航：不改 NavigationBar，在「个人资料」页中加入口
- 每页帖数：从 API `ppp` 字段读取，不硬编码
- Provider 风格：`StateNotifierProvider` + `extends StateNotifier`（与项目现有一致）

## 设计决策摘要

| # | 决策点 | 结论 |
|---|--------|------|
| D1 | Provider API 风格 | `StateNotifier`，保持一致 |
| D2 | 副作用监听方式 | `build()` 中 `ref.listen`，非 initState |
| D3 | ThreadCard widget 类型 | 整体改为 `ConsumerWidget` |
| D4 | 进度条刷新时序 | 接受列表页不立即刷新的限制 |
| D5 | 续读交互 | 双层：ThreadCard 直跳 + SnackBar 备用提示 |
| D6 | `_ThreadPageSheet._perPage` | 硬编码 40→30 |
| D7 | `_HistoryTile` 风格 | 丰富信息式（版块名、阅读次数、时间） |
| D8 | `readCount` 字段 | 新增，每次进入详情页 +1，翻页不计 |
| D9 | 版块名获取 | 通过 `forumListProvider` 查 fid，未加载则不显示 |
| D10 | 用户隔离 | 单 Box，key 加 `{uid}_` 前缀，未登录用 `guest_` |
| D11 | 记录上限 | 500 条，不变 |
| D12 | 单元测试 | 不需要，手动测试 |

---

## 已发现的预置问题（本计划一并修复）

| # | 问题 | 位置 | 修复 |
|---|------|------|------|
| P1 | `_calcTotalPages` 硬编码 `perPage=40` | [thread_card.dart:12](file:///d:/Project/s1-app/lib/widgets/thread_card.dart#L12) | 改为 30 |
| P2 | `thread_detail_screen.dart:173` 硬编码 `* 30` | [thread_detail_screen.dart:173](file:///d:/Project/s1-app/lib/screens/thread_detail_screen.dart#L173) | 改为 `state.perPage` |
| P3 | `_ThreadPageSheet._perPage = 40` | [thread_card.dart:311](file:///d:/Project/s1-app/lib/widgets/thread_card.dart#L311) | 改为 30 |

---

## 实现任务

### Phase 1：数据层

#### 1.1 新建 `lib/models/reading_record.dart`

纯 Dart 类，无 Flutter 依赖。新增 `readCount` 字段。

```dart
class ReadingRecord {
  ReadingRecord({
    required this.tid,
    required this.subject,
    required this.author,
    required this.fid,
    required this.lastReadPage,
    required this.lastReadFloor,
    required this.totalPages,
    required this.totalReplies,
    required this.perPage,
    required this.lastReadAt,
    required this.firstReadAt,
    this.readCount = 1,
  });

  final String tid;
  final String subject;
  final String author;
  final String fid;
  final int lastReadPage;
  final int lastReadFloor;
  final int totalPages;
  final int totalReplies;
  final int perPage;
  final int lastReadAt;   // millisecondsSinceEpoch
  final int firstReadAt;  // millisecondsSinceEpoch
  final int readCount;    // 进入详情页次数

  /// 进度 = 当前页 / 总页数
  double get progress => totalPages > 0
      ? (lastReadPage / totalPages).clamp(0.0, 1.0)
      : 0.0;

  /// 读完 = 绝对楼层 >= 总帖子数（主楼+回复）
  /// 当前实现假设「加载某页 = 阅读完该页所有帖子」
  bool get isFinished => totalReplies > 0 && lastReadFloor >= totalReplies + 1;

  Map<String, dynamic> toJson() => { /* 所有字段 */ };
  factory ReadingRecord.fromJson(Map<String, dynamic> json) => /* 解析 */;
  ReadingRecord copyWith({ /* 可选字段 */ });
}
```

#### 1.2 新建 `lib/services/reading_history_service.dart`

接收已打开的 `Box<Map>`。key 格式为 `{uid}_{tid}`，通过构造函数传入当前 uid。

```dart
class ReadingHistoryService {
  ReadingHistoryService(this._box, this._uid);
  final Box<Map> _box;
  final String _uid; // 当前用户 UID，未登录时为 'guest'
  static const int _maxRecords = 500;

  String _key(String tid) => '${_uid}_$tid';

  void updateProgress({
    required String tid,
    required int page,
    required int floorInPage,
    required String subject,
    required String author,
    required String fid,
    required int totalPages,
    required int totalReplies,
    required int perPage,
    bool isNewVisit = false, // 是否为本次会话首次加载
  }) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final absoluteFloor = (page - 1) * perPage + floorInPage;
    final key = _key(tid);
    final existing = _box.get(key);
    final firstReadAt = existing != null
        ? (existing['firstReadAt'] as int? ?? now)
        : now;
    final prevCount = existing != null
        ? (existing['readCount'] as int? ?? 0)
        : 0;

    final record = ReadingRecord(
      tid: tid, subject: subject, author: author, fid: fid,
      lastReadPage: page, lastReadFloor: absoluteFloor,
      totalPages: totalPages, totalReplies: totalReplies,
      perPage: perPage, lastReadAt: now, firstReadAt: firstReadAt,
      readCount: isNewVisit ? prevCount + 1 : prevCount,
    );
    _box.put(key, record.toJson());
    _evictIfNeeded();
  }

  ReadingRecord? getRecord(String tid) { /* 用 _key(tid) 读取 */ }

  List<ReadingRecord> getAllRecords() {
    // 过滤当前 uid 的记录，按 lastReadAt 倒序
    return _box.toMap().entries
        .where((e) => e.key.toString().startsWith('${_uid}_'))
        .map((e) => ReadingRecord.fromJson(Map<String, dynamic>.from(e.value as Map)))
        .toList()
      ..sort((a, b) => b.lastReadAt.compareTo(a.lastReadAt));
  }

  void deleteRecord(String tid) { _box.delete(_key(tid)); }

  Future<void> clearAll() async {
    // 只清除当前 uid 的记录
    final keys = _box.keys.where((k) => k.toString().startsWith('${_uid}_')).toList();
    for (final key in keys) {
      await _box.delete(key);
    }
  }

  void _evictIfNeeded() {
    final userRecords = _box.keys.where((k) => k.toString().startsWith('${_uid}_')).toList();
    if (userRecords.length <= _maxRecords) return;
    // 按 lastReadAt 正序，删除最旧的
    final entries = userRecords
        .map((k) => MapEntry(k, _box.get(k) as Map))
        .toList()
      ..sort((a, b) => ((a.value['lastReadAt'] as int?) ?? 0)
          .compareTo((b.value['lastReadAt'] as int?) ?? 0));
    for (var i = 0; i < userRecords.length - _maxRecords; i++) {
      _box.delete(entries[i].key);
    }
  }
}
```

#### 1.3 修改 `lib/main.dart`

在 `await Hive.openBox('cache');` 之后添加：

```dart
await Hive.openBox<Map>('reading_history');
```

---

### Phase 2：Provider 层

#### 2.1 新建 `lib/providers/reading_history_provider.dart`

使用 `StateNotifierProvider` 风格。`readingHistoryServiceProvider` 依赖 `authStateProvider` 获取 UID。

```dart
final readingBoxProvider = Provider<Box<Map>>((ref) {
  return Hive.box<Map>('reading_history');
});

final readingHistoryServiceProvider = Provider<ReadingHistoryService>((ref) {
  final box = ref.watch(readingBoxProvider);
  final authState = ref.watch(authStateProvider);
  final uid = authState.user?.uid ?? 'guest';
  return ReadingHistoryService(box, uid);
});

final readingRecordProvider = Provider.family<ReadingRecord?, String>((ref, tid) {
  return ref.watch(readingHistoryServiceProvider).getRecord(tid);
});

final readingHistoryProvider =
    StateNotifierProvider<ReadingHistoryNotifier, List<ReadingRecord>>((ref) {
  return ReadingHistoryNotifier(ref.watch(readingHistoryServiceProvider));
});

class ReadingHistoryNotifier extends StateNotifier<List<ReadingRecord>> {
  ReadingHistoryNotifier(this._service) : super(_service.getAllRecords());
  final ReadingHistoryService _service;

  void refresh() => state = _service.getAllRecords();

  void delete(String tid) {
    _service.deleteRecord(tid);
    state = _service.getAllRecords();
  }

  Future<void> clearAll() async {
    await _service.clearAll();
    state = [];
  }
}
```

#### 2.2 修改 `lib/providers/post_provider.dart`

在 `PostListState` 中新增 `perPage` 和 `totalReplies` 字段。
在 `PostNotifier._loadPage()` 中，统一提取 `variables` 后获取 perPage/totalReplies，避免重复 JSON 遍历：

```dart
Future<void> _loadPage(int page) async {
  state = const AsyncValue.loading();
  try {
    final result = await _apiService.getThreadDetail(tid, page: page);
    final posts = ApiService.parsePostList(result);
    final variables = result['Variables'] as Map<String, dynamic>? ?? {};
    final threadMap = variables['thread'] as Map<String, dynamic>? ?? {};
    final perPage = int.tryParse(variables['ppp']?.toString() ?? '') ?? 30;
    final totalReplies = int.tryParse(threadMap['replies']?.toString() ?? '') ?? 0;
    final totalPosts = totalReplies + 1;
    final totalPages = (totalPosts / perPage).ceil().clamp(1, 9999);
    final subject = threadMap['subject']?.toString();
    final fid = threadMap['fid']?.toString();

    state = AsyncValue.data(PostListState(
      posts: posts,
      currentPage: page,
      totalPages: totalPages,
      threadSubject: subject,
      threadFid: fid,
      perPage: perPage,
      totalReplies: totalReplies,
    ));
  } catch (e, st) {
    state = AsyncValue.error(e, st);
  }
}
```

---

### Phase 3：UI 集成

#### 3.1 修改 `lib/screens/thread_detail_screen.dart`

在 build 中使用 `ref.listen`。

```dart
bool _hasRecordedInitialVisit = false;
bool _hasCheckedResume = false;

@override
Widget build(BuildContext context) {
  ref.listen(postProvider(widget.tid), (previous, next) {
    next.whenData((state) {
      _recordProgress(state);
      if (widget.initialPage == null) {
        _checkResumeReading(state);
      }
    });
  });

  final postsAsync = ref.watch(postProvider(widget.tid));
  // ...
}
```

并修复楼层计算：
```dart
final floorOffset = (state.currentPage - 1) * state.perPage;
```

#### 3.2 修改 `lib/widgets/thread_card.dart`

- 改为 `ConsumerWidget`
- 修改 `_calcTotalPages` 默认 `perPage = 30`
- 修改 `_ThreadPageSheet._perPage = 30`
- onTap 支持续读跳转
- 引用 `_ReadingProgressBar` widget

#### 3.3 新建 `lib/screens/reading_history_screen.dart`

ConsumerWidget。使用丰富信息式 `_HistoryTile`，通过 `forumListProvider` 解析 fid 显示版块名称。支持 Dismissible 侧滑删除与弹窗清空。

#### 3.4 修改 `lib/screens/profile_screen.dart`

在 `ProfileBody` 中加入“阅读历史”的 ListTile 卡片，通过 `Consumer` 显示当前的记录数量。

#### 3.5 修改 `lib/app.dart`

加入 `/reading-history` 路由。

---

### Phase 4：验证与测试

通过静态分析、现有测试集与 T1-T13 的手动测试矩阵保证功能质量。
