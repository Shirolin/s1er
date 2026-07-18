# 阅读历史 + 阅读进度 — 最终实现计划

> 版本：v1.1（2026-07-09 基于真实代码核对修正）｜本文件为**权威实现计划**，与 `docs/plans/reading_history_design.md` 冲突处以本文件为准。

## 目标

为 S1 客户端添加本地阅读历史记录和阅读进度追踪功能。用户进入帖子时自动记录，再次打开时可续读，帖子列表中显示进度标识。

---

## ⚠️ v1.1 勘误与修正（基于真实代码 + `docs/api_reference.md` 核对）

> 下列为核对真实代码后发现的 v1.0 计划错误，均已在本文档正文同步修正。实施时务必以修正后的结论为准。

### C1【最关键】每页帖数是 `ppp = 40`，不是 30

v1.0 计划（D6/P1/P3）主张把每页帖数统一为 **30** —— **方向错了**。依据 `docs/api_reference.md`（§`ppp`、§已知陷阱 #5）：

- 帖子**详情页**（`viewthread`）每页帖数字段是 **`ppp`，实际值 `40`**。
- 版块**主题列表**（`forumdisplay`）每页主题数字段是 **`tpp`，实际值 `50`**，与 `ppp` 是两码事，**不可混用**。

对照真实代码：

| 位置 | 现状 | 正确性 | 结论 |
|---|---|---|---|
| `lib/widgets/thread_card.dart:12` `_calcTotalPages(..., perPage = 40)` | 40 | ✅ 与 `ppp` 一致 | **保留 40**（v1.0 要改 30 是错的） |
| `lib/widgets/thread_card.dart:311` `_ThreadPageSheet._perPage = 40` | 40 | ✅ 与 `ppp` 一致 | **保留 40**（v1.0 要改 30 是错的） |
| `lib/screens/thread_detail_screen.dart:173` `(state.currentPage - 1) * 30` | 30 | ❌ **真正的 bug** | 改为 `state.perPage`（来自 API `ppp`） |
| `lib/providers/post_provider.dart:90` `ppp` fallback `?? 30` | 30 | ❌ fallback 应与 `ppp` 一致 | fallback 改为 **40** |

**统一原则**：详情页一律读 API 的 `ppp`（`PostListState.perPage`）；无法拿到 API 值的地方（`ThreadCard` 只有列表数据、没有 `ppp`）用**共享 fallback 常量 = 40**。建议新增 `S1Constants.postsPerPageFallback = 40`，消灭所有散落的 `30`/`40` 字面量。

### C2 `isFinished` / `progress` 语义统一为「楼级」

详情页已通过可见楼滚动回写精确的 `lastReadFloor`，进度与已读判定必须以楼层为准（不再用 `lastReadPage`）：

- `totalPosts = totalReplies + 1`
- `progress = totalPosts > 0 ? (lastReadFloor / totalPosts).clamp(0,1) : 0`
- `isFinished = lastReadFloor >= totalPosts`
- 列表 live：`progressAt` / `isFinishedAt` / `hasNewReplies` 对照 `thread.replies`
- `resolveOpenPage` 由楼层推页；B3（已读后有新回复）落到首个未读楼 `totalPosts + 1` 所在页顶
- `lastReadPage` 仍写入存储作冗余，**不参与**进度/已读/开页
- UI 文案：未读完 `#45`，有新回复 `#45/320`，读完「已读」

0 回复帖：`totalPosts == 1 && lastReadFloor >= 1 ⇒ 已读`。末页只读一半时楼级判未读完（修正页级误标「已读」）。

### C3 用户隔离 key 前缀要兼容「uid 为空串」

`User.uid` 缺省是**空字符串 `''` 而非 `null`**（见 `lib/models/user.dart:24`），且 Web 端登录后 `uid` 会短暂为 `''`（`AuthService.login` 先建 `User(uid:'')` 再异步 `fetchProfile` 补全）。因此 `authState.user?.uid ?? 'guest'` 在 uid 为 `''` 时会得到前缀 `_{tid}`，污染数据。**必须**：

```dart
final rawUid = ref.watch(authStateProvider).user?.uid;
final uid = (rawUid == null || rawUid.isEmpty) ? 'guest' : rawUid;
```

### C4 单条记录 Provider 需显式失效才会刷新

`readingRecordProvider` 是 `Provider.family`，读取一次后会缓存。写入进度后，若不 `ref.invalidate(readingRecordProvider(tid))`，`ThreadCard` 的进度条不会更新。故 `_recordProgress` 写库后必须失效该 provider（列表页因已在别的路由，遵循 D4：返回列表时随页面重建刷新，可接受）。

### C5 其它与真实代码对齐的确认

- `PostListState`（`lib/providers/post_provider.dart:6`）当前**没有** `perPage`/`totalReplies` 字段，需按 §2.2 新增。
- 详情页现用 `initState` + `addPostFrameCallback` 处理 `initialPage` 跳转；本计划改用 `build()` 内 `ref.listen`（D2）记录进度，二者不冲突。
- 路由 `/thread/:tid` 已支持 `?page=` query（`lib/app.dart:31`），续读跳转直接复用。
- 项目 Provider 风格**混用**：`auth/post/settings` 用 `StateNotifier`，`forum_list` 用 `AsyncNotifier`；本计划的可变列表 Notifier 采用 `StateNotifier`（D1），与 `settings/auth` 一致。设计文档 v1.0 用 `NotifierProvider` 属笔误。
- 导航方案：**在「个人资料」页加入口**（前置约束），**不改 `NavigationBar`**。设计文档 v1.0 §6.4「方案 A：替换搜索 Tab」与此冲突，**以本文件为准，废弃方案 A**。

---

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
| D6 | 每页帖数来源 | 详情页读 API `ppp`；无 API 值处用共享 fallback 常量 **40**（见 C1，**修正 v1.0 的 30**） |
| D7 | `_HistoryTile` 风格 | 丰富信息式（版块名、阅读次数、时间） |
| D8 | `readCount` 字段 | 新增，每次进入详情页 +1，翻页不计 |
| D9 | 版块名获取 | 通过 `forumListProvider` 查 fid，未加载则不显示 |
| D10 | 用户隔离 | 单 Box，key 加 `{uid}_` 前缀，未登录用 `guest_` |
| D11 | 记录上限 | 500 条，不变 |
| D12 | 单元测试 | 不需要，手动测试 |

---

## 已发现的预置问题（本计划一并修复）

> 依据：`docs/api_reference.md` 认定 `viewthread` 的 `ppp = 40`（见 C1）。故真正要修的是**详情页硬编码的 30**，而非 `thread_card` 的 40。

| # | 问题 | 位置 | 修复 |
|---|------|------|------|
| P1 | `_calcTotalPages` 的 fallback `perPage` 应与 `ppp` 一致 | `lib/widgets/thread_card.dart:12` | 用共享常量 `S1Constants.postsPerPageFallback = 40`（值不变，去字面量） |
| P2 | 硬编码 `* 30`，与 API `ppp=40` 不符（**真 bug**） | `lib/screens/thread_detail_screen.dart:173` | 改为 `state.perPage`（来自 API `ppp`） |
| P3 | `_ThreadPageSheet._perPage = 40` 是散落字面量 | `lib/widgets/thread_card.dart:311` | 引用共享常量 `S1Constants.postsPerPageFallback`（值仍为 40） |
| P4 | `post_provider` 的 `ppp` fallback `?? 30` 与 `ppp=40` 不符 | `lib/providers/post_provider.dart:90` | fallback 改为 `40`（或引用共享常量） |

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

  /// 进度 = 已读楼 / 总楼（楼级，见 C2）
  double get progress => totalPosts > 0
      ? (lastReadFloor / totalPosts).clamp(0.0, 1.0)
      : 0.0;

  /// 读完 = 已读到最后一楼（楼级）；0 回复帖 lastReadFloor>=1 即已读。
  /// lastReadPage 仅存储冗余，不参与判定。
  bool get isFinished => lastReadFloor >= totalPosts;

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

#### 1.4 新增共享常量 `lib/config/constants.dart`

消灭散落的 `30`/`40` 字面量（C1/P1/P3/P4）。`S1Constants` 已存在（含 `mobileUserAgent`、`maxRequestsPerSecond`），追加：

```dart
/// 帖子详情页每页帖数的兜底值。
/// 权威来源是 API 的 ppp 字段（viewthread，实际 40）；
/// 仅在拿不到 API 值时（如 ThreadCard 只有列表数据）使用。
/// 注意：勿与 forumdisplay 的 tpp(=50，主题列表每页数) 混用。
static const int postsPerPageFallback = 40;
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
  // C3：User.uid 缺省为空串 ''（非 null），Web 端登录后会短暂为 ''，
  // 必须把空串也归到 guest，否则 key 前缀会变成 "_{tid}" 污染数据。
  final rawUid = authState.user?.uid;
  final uid = (rawUid == null || rawUid.isEmpty) ? 'guest' : rawUid;
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
    final perPage = int.tryParse(variables['ppp']?.toString() ?? '')
        ?? S1Constants.postsPerPageFallback; // C1/P4：fallback = 40，不是 30
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

并修复楼层计算（P2，替换硬编码 `* 30`）：
```dart
final floorOffset = (state.currentPage - 1) * state.perPage;
```

**关键细节：**

- `_recordProgress(state)` 写库后必须失效单条 provider，否则列表进度条不刷新（C4）：
  ```dart
  ref.read(readingHistoryServiceProvider).updateProgress(
    tid: widget.tid,
    page: state.currentPage,
    floorInPage: state.posts.length, // 当前页最后一楼的页内序号
    subject: state.threadSubject ?? '',
    author: state.posts.isNotEmpty ? state.posts.first.author : '',
    fid: state.threadFid ?? '',
    totalPages: state.totalPages,
    totalReplies: state.totalReplies,
    perPage: state.perPage,
    isNewVisit: !_hasRecordedInitialVisit,
  );
  ref.invalidate(readingRecordProvider(widget.tid));
  _hasRecordedInitialVisit = true;
  ```
- `readCount +1` 只在本次进入详情页的**首帧**发生（`isNewVisit` 由 `_hasRecordedInitialVisit` 守卫）。翻页、`refresh()` 都会再次触发 `ref.listen` 的 data 回调，但此时 `isNewVisit=false`，不重复计数（对应 D8）。
- `_checkResumeReading` 用 `_hasCheckedResume` 守卫，避免每次 data 回调都弹 SnackBar。

#### 3.2 修改 `lib/widgets/thread_card.dart`

- 改为 `ConsumerWidget`
- `_calcTotalPages` 的 fallback 用 `S1Constants.postsPerPageFallback`（**= 40**，见 C1；**不是 30**）
- `_ThreadPageSheet._perPage` 引用 `S1Constants.postsPerPageFallback`（值仍为 40）
- onTap 支持续读跳转：读 `readingRecordProvider(thread.tid)`，若存在且 `!isFinished && lastReadPage > 1`，`push('/thread/${tid}?page=${lastReadPage}')`，否则 `push('/thread/${tid}')`
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

---

## 边界情况与验收（v1.1 补充）

### 边界情况

| 场景 | 处理 |
|---|---|
| 0 回复帖（仅主楼） | `totalPosts=1`、`lastReadFloor>=1` ⇒ `isFinished=true` |
| 末页只读一半 | `lastReadPage==totalPages` 但 `lastReadFloor < totalPosts` ⇒ 未读完（楼级修正） |
| API 未返回 `ppp` | 用 `S1Constants.postsPerPageFallback = 40`（C1） |
| 未登录 / uid 为空串 | key 前缀归一到 `guest_`（C3） |
| 登录态在启动时异步恢复 | `checkSession()` 完成前写入的记录会落到 `guest_`；`authStateProvider` 就绪后 `readingHistoryCoordinatorProvider` 监听 uid 变化，将 `guest_*` 合并到真实 uid 命名空间（幂等） |
| 切换账号 | 因 key 带 `{uid}_` 前缀，天然隔离；淘汰 `_evictIfNeeded` 也按当前 uid 计数（优于设计文档 v1.0 的全局 `_box.length`） |
| 帖子标题/页数变化 | 每次进入用最新值覆盖缓存 |
| 列表页进度条不实时刷新 | 遵循 D4：返回列表页触发重建时刷新；详情页内写库后 `invalidate(readingRecordProvider(tid))`（C4） |

### 验收标准

- [ ] 进入详情页自动创建/更新记录；`readCount` 每次进入 +1，翻页不 +1（D8）
- [ ] 翻页后页码/进度更新；楼层号用 `state.perPage`（=API `ppp`）计算，不再出现 `*30` 偏差（P2）
- [ ] 列表卡片 `N页` 与详情页总页数一致（同用 `ppp`/fallback 40，C1）
- [ ] 已读帖再次点击可续读到上次楼层；0 回复帖显示「已读」；末页半读不标「已读」
- [ ] 列表/历史进度文案为 `#楼` / `#楼/总楼`，非 `P页`
- [ ] 历史页按 `lastReadAt` 倒序；支持单条删除与清空（仅当前 uid）
- [ ] 超过 500 条（按 uid 计）淘汰最旧
- [ ] 全程无网络依赖
- [ ] `flutter analyze` 无 error/warning；`flutter test` 通过
