# 阅读历史 + 阅读进度 方案设计

> 版本：v1.0 | 日期：2026-07-09
>
> ⚠️ **本设计文档为早期草案，部分决策已被 `docs/reading-history-plan.md`（v1.1 最终实现计划）修正/推翻。实施以最终计划为准。** 下列条目在本文中不要照抄：

| 本文位置 | 早期写法（勿用） | 最终结论（见 reading-history-plan.md） |
|---|---|---|
| §4.1 `updateProgress` | `absoluteFloor = (page-1) * 30 + floorInPage`（硬编码 30） | 每页帖数是 API `ppp = 40`；用 `record.perPage`，fallback 常量 40（C1/P2） |
| §2.1 `isFinished` | `lastReadPage >= totalPages`（此处正确） / 最终计划正文曾用楼层级公式 | 统一「页级」`lastReadPage >= totalPages`，修正 0 回复 bug（C2） |
| §5.3 `NotifierProvider`/`Notifier` | 新式 Notifier | 用 `StateNotifierProvider`/`StateNotifier`，与 `auth/post/settings` 一致（D1） |
| §5.1 `Service.init()` in provider | Service 内部 `openBox` | Box 在 `main.dart` 打开，Service 接收已打开的 `Box<Map>` + 当前 uid（D10） |
| §6.1 `totalReplies: 0 // TODO` | 传 0 占位 | 从 `variables['thread']['replies']` 提取，存入 `PostListState.totalReplies`（§2.2） |
| §6.4 方案 A：替换「搜索」Tab 为「历史」Tab | 改 `NavigationBar` | **不改 NavigationBar**，在「个人资料」页加入口（前置约束，废弃方案 A） |
| §4.1 `_evictIfNeeded` 用 `_box.length` | 全局计数淘汰 | 按当前 uid 前缀计数淘汰，避免多账号相互挤占（D10/C5） |
| 用户隔离 | 无（key 直接用 tid） | key 加 `{uid}_` 前缀，uid 为空串归 `guest`（C3/D10） |

## 1. 需求概述

### 1.1 核心功能

| # | 功能 | 说明 |
|---|------|------|
| F1 | 阅读记录自动采集 | 用户进入帖子详情页时自动记录，无需手动操作 |
| F2 | 阅读进度追踪 | 记录最后阅读的页码 + 楼层，精确到帖子级别 |
| F3 | 续读跳转 | 再次打开已读帖子时，自动/手动跳转到上次位置 |
| F4 | 阅读历史列表 | 按最后阅读时间倒序展示，支持搜索和清除 |
| F5 | 帖子卡片进度标识 | 在帖子列表中用视觉标记区分已读/未读/部分阅读 |
| F6 | 离线可查 | 历史记录本地持久化，无需网络 |

### 1.2 非功能需求

- 存储上限：500 条记录（LRU 淘汰）
- 性能：读写操作 < 5ms（Hive 本地 KV）
- 兼容性：不引入新依赖，复用现有 Hive
- 数据流：遵守项目架构边界，Screen → Provider → Service → Hive

---

## 2. 数据模型

### 2.1 ReadingRecord

```dart
// lib/models/reading_record.dart

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
    required this.lastReadAt,
    required this.firstReadAt,
  });

  final String tid;           // 帖子 ID（主键）
  final String subject;       // 帖子标题（缓存，用于离线展示）
  final String author;        // 作者名（缓存）
  final String fid;           // 版块 ID（缓存）
  final int lastReadPage;     // 最后阅读页码（1-based）
  final int lastReadFloor;    // 最后阅读的绝对楼层（1-based，跨页计算）
  final int totalPages;       // 帖子总页数（缓存）
  final int totalReplies;     // 帖子总回复数（缓存）
  final int lastReadAt;       // 最后阅读时间（Unix ms）
  final int firstReadAt;      // 首次阅读时间（Unix ms）

  /// 阅读进度 0.0 ~ 1.0
  double get progress {
    final totalPosts = totalReplies + 1; // 主楼 + 回复
    if (totalPosts <= 0) return 1.0;
    return (lastReadFloor / totalPosts).clamp(0.0, 1.0);
  }

  /// 是否已读完（最后一页）
  bool get isFinished => lastReadPage >= totalPages;

  /// 用于 Hive 存储的序列化
  Map<String, dynamic> toJson() => {
    'tid': tid,
    'subject': subject,
    'author': author,
    'fid': fid,
    'lastReadPage': lastReadPage,
    'lastReadFloor': lastReadFloor,
    'totalPages': totalPages,
    'totalReplies': totalReplies,
    'lastReadAt': lastReadAt,
    'firstReadAt': firstReadAt,
  };

  factory ReadingRecord.fromJson(Map<String, dynamic> json) {
    return ReadingRecord(
      tid: json['tid']?.toString() ?? '',
      subject: json['subject']?.toString() ?? '',
      author: json['author']?.toString() ?? '',
      fid: json['fid']?.toString() ?? '',
      lastReadPage: json['lastReadPage'] as int? ?? 1,
      lastReadFloor: json['lastReadFloor'] as int? ?? 1,
      totalPages: json['totalPages'] as int? ?? 1,
      totalReplies: json['totalReplies'] as int? ?? 0,
      lastReadAt: json['lastReadAt'] as int? ?? 0,
      firstReadAt: json['firstReadAt'] as int? ?? 0,
    );
  }

  ReadingRecord copyWith({
    String? subject,
    String? author,
    String? fid,
    int? lastReadPage,
    int? lastReadFloor,
    int? totalPages,
    int? totalReplies,
    int? lastReadAt,
  }) {
    return ReadingRecord(
      tid: tid,
      subject: subject ?? this.subject,
      author: author ?? this.author,
      fid: fid ?? this.fid,
      lastReadPage: lastReadPage ?? this.lastReadPage,
      lastReadFloor: lastReadFloor ?? this.lastReadFloor,
      totalPages: totalPages ?? this.totalPages,
      totalReplies: totalReplies ?? this.totalReplies,
      lastReadAt: lastReadAt ?? this.lastReadAt,
      firstReadAt: firstReadAt,
    );
  }
}
```

### 2.2 数据关系图

```
┌─────────────────────────────────────────────────────────┐
│                     Hive Box: reading_history            │
│                                                         │
│  Key (String)    Value (Map<String, dynamic>)            │
│  ─────────────   ──────────────────────────────────────  │
│  "123456"        { tid, subject, author, fid, ... }      │
│  "789012"        { tid, subject, author, fid, ... }      │
│  ...             ...                                     │
│                                                         │
│  最大 500 条，LRU 淘汰最久未访问的记录                       │
└─────────────────────────────────────────────────────────┘
```

---

## 3. 架构设计

### 3.1 层次结构

```
┌───────────────────────────────────────────────────────────────┐
│  UI Layer                                                     │
│  ┌─────────────┐ ┌──────────────┐ ┌────────────────────────┐  │
│  │ThreadDetail │ │ ThreadCard   │ │ ReadingHistoryScreen   │  │
│  │Screen       │ │ (进度指示器)  │ │ (历史列表)              │  │
│  └──────┬──────┘ └──────┬───────┘ └───────────┬────────────┘  │
├─────────┼───────────────┼─────────────────────┼───────────────┤
│  Provider Layer                                               │
│  ┌──────┴──────┐ ┌──────┴───────┐ ┌───────────┴────────────┐  │
│  │postProvider │ │ readingRecord│ │ readingHistoryProvider  │  │
│  │(已存在)     │ │ Provider     │ │ (列表 + 操作)           │  │
│  └──────┬──────┘ └──────┬───────┘ └───────────┬────────────┘  │
├─────────┼───────────────┼─────────────────────┼───────────────┤
│  Service Layer                                                │
│  ┌──────┴──────────────────────────────────────────────────┐  │
│  │              ReadingHistoryService                       │  │
│  │  - updateProgress(tid, page, floor, ...)                │  │
│  │  - getRecord(tid) → ReadingRecord?                      │  │
│  │  - getAllRecords() → List<ReadingRecord>                 │  │
│  │  - deleteRecord(tid)                                    │  │
│  │  - clearAll()                                           │  │
│  └──────┬──────────────────────────────────────────────────┘  │
├─────────┼─────────────────────────────────────────────────────┤
│  Storage Layer                                                │
│  ┌──────┴──────────────────────────────────────────────────┐  │
│  │                 Hive Box: reading_history                │  │
│  └─────────────────────────────────────────────────────────┘  │
└───────────────────────────────────────────────────────────────┘
```

### 3.2 数据流

```
用户翻页 / 滚动
      │
      ▼
ThreadDetailScreen._onPageChanged()
      │
      ▼
ref.read(readingHistoryServiceProvider).updateProgress(
  tid, page, floor, subject, author, fid, totalPages, totalReplies
)
      │
      ▼
ReadingHistoryService → Hive Box 写入
      │
      ▼
ref.invalidate(readingRecordProvider(tid))  // 刷新单条记录
ref.invalidate(readingHistoryProvider)       // 刷新历史列表
```

---

## 4. Service 层实现

### 4.1 ReadingHistoryService

```dart
// lib/services/reading_history_service.dart

class ReadingHistoryService {
  static const String _boxName = 'reading_history';
  static const int _maxRecords = 500;
  late Box<Map> _box;

  Future<void> init() async {
    _box = await Hive.openBox<Map>(_boxName);
  }

  /// 更新阅读进度（核心方法）
  /// 如果记录不存在则创建，存在则更新
  void updateProgress({
    required String tid,
    required int page,
    required int floorInPage,
    required String subject,
    required String author,
    required String fid,
    required int totalPages,
    required int totalReplies,
  }) {
    final now = DateTime.now().millisecondsSinceEpoch;
    // ⚠️ 勿硬编码 30：每页帖数是 API ppp（=40）。改用传入的 perPage 参数。见最终计划 C1。
    final absoluteFloor = (page - 1) * perPage + floorInPage;
    final existing = _box.get(tid);
    final firstReadAt = existing != null
        ? (existing['firstReadAt'] as int? ?? now)
        : now;

    final record = ReadingRecord(
      tid: tid,
      subject: subject,
      author: author,
      fid: fid,
      lastReadPage: page,
      lastReadFloor: absoluteFloor,
      totalPages: totalPages,
      totalReplies: totalReplies,
      lastReadAt: now,
      firstReadAt: firstReadAt,
    );

    _box.put(tid, record.toJson());
    _evictIfNeeded();
  }

  /// 获取单条记录
  ReadingRecord? getRecord(String tid) {
    final data = _box.get(tid);
    if (data == null) return null;
    return ReadingRecord.fromJson(Map<String, dynamic>.from(data));
  }

  /// 获取所有记录，按最后阅读时间倒序
  List<ReadingRecord> getAllRecords() {
    final records = _box.values
        .map((m) => ReadingRecord.fromJson(Map<String, dynamic>.from(m)))
        .toList();
    records.sort((a, b) => b.lastReadAt.compareTo(a.lastReadAt));
    return records;
  }

  /// 删除单条记录
  void deleteRecord(String tid) {
    _box.delete(tid);
  }

  /// 清空所有记录
  Future<void> clearAll() async {
    await _box.clear();
  }

  /// 获取记录总数
  int get count => _box.length;

  /// LRU 淘汰：超过上限时删除最旧的记录
  void _evictIfNeeded() {
    if (_box.length <= _maxRecords) return;

    final entries = _box.toMap().entries.toList()
      ..sort((a, b) {
        final aTime = (a.value as Map)['lastReadAt'] as int? ?? 0;
        final bTime = (b.value as Map)['lastReadAt'] as int? ?? 0;
        return aTime.compareTo(bTime); // 正序，最旧在前
      });

    final toRemove = _box.length - _maxRecords;
    for (var i = 0; i < toRemove; i++) {
      _box.delete(entries[i].key);
    }
  }
}
```

---

## 5. Provider 层实现

### 5.1 Service Provider

```dart
// lib/providers/reading_history_provider.dart

final readingHistoryServiceProvider = Provider<ReadingHistoryService>((ref) {
  final service = ReadingHistoryService();
  // 注意：init() 在 main.dart 中提前调用
  return service;
});
```

### 5.2 单条记录 Provider（family by tid）

```dart
/// 查询单条帖子的阅读记录，用于 ThreadCard 和 ThreadDetailScreen
final readingRecordProvider = Provider.family<ReadingRecord?, String>((ref, tid) {
  return ref.watch(readingHistoryServiceProvider).getRecord(tid);
});
```

### 5.3 历史列表 Provider

```dart
/// 阅读历史列表，用于历史页面展示
final readingHistoryProvider =
    NotifierProvider<ReadingHistoryNotifier, List<ReadingRecord>>(
  () => ReadingHistoryNotifier(),
);

class ReadingHistoryNotifier extends Notifier<List<ReadingRecord>> {
  @override
  List<ReadingRecord> build() {
    return ref.read(readingHistoryServiceProvider).getAllRecords();
  }

  void refresh() {
    state = ref.read(readingHistoryServiceProvider).getAllRecords();
  }

  void delete(String tid) {
    ref.read(readingHistoryServiceProvider).deleteRecord(tid);
    state = ref.read(readingHistoryServiceProvider).getAllRecords();
  }

  Future<void> clearAll() async {
    await ref.read(readingHistoryServiceProvider).clearAll();
    state = [];
  }
}
```

---

## 6. UI 集成方案

### 6.1 ThreadDetailScreen 改动

**改动点：记录阅读进度**

```dart
// 在 _ThreadDetailScreenState 中添加

void _recordProgress(int page, List<Post> posts) {
  final postState = ref.read(postProvider(widget.tid)).valueOrNull;
  if (postState == null) return;

  ref.read(readingHistoryServiceProvider).updateProgress(
    tid: widget.tid,
    page: page,
    floorInPage: posts.length, // 当前页最后一条帖子的页内序号
    subject: postState.threadSubject ?? '',
    author: posts.isNotEmpty ? posts.first.author : '',
    fid: postState.threadFid ?? '',
    totalPages: postState.totalPages,
    totalReplies: postState.totalReplies, // ⚠️ 勿传 0：从 PostListState.totalReplies 取（见最终计划 §2.2）
    perPage: postState.perPage,           // 来自 API ppp
  );
  // 刷新相关 provider
  ref.invalidate(readingRecordProvider(widget.tid));
}
```

**触发时机：**
1. 页面加载完成时（`_loadPage` 成功后）
2. 用户翻页时（`goToPage` 成功后）
3. 用户滚动到新帖子时（可选，节流）

**改动点：续读提示**

```dart
// 在 build 方法中，当 initialPage 为 null 时检查是否有历史记录
@override
void initState() {
  super.initState();
  // ... existing code ...

  // 检查是否有阅读记录，提示续读
  WidgetsBinding.instance.addPostFrameCallback((_) {
    _checkResumeReading();
  });
}

void _checkResumeReading() {
  final record = ref.read(readingRecordProvider(widget.tid));
  if (record != null && !record.isFinished && record.lastReadPage > 1) {
    _showResumeSnackBar(record);
  }
}

void _showResumeSnackBar(ReadingRecord record) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text('上次阅读到第 ${record.lastReadPage} 页'),
      action: SnackBarAction(
        label: '跳转',
        onPressed: () {
          ref.read(postProvider(widget.tid).notifier)
              .goToPage(record.lastReadPage);
        },
      ),
      duration: const Duration(seconds: 5),
    ),
  );
}
```

### 6.2 ThreadCard 改动

**改动点：显示阅读进度指示器**

```dart
// 在 ThreadCard 的 build 方法中

@override
Widget build(BuildContext context) {
  // ... existing code ...

  return Card(
    // ... existing decoration ...
    child: InkWell(
      onTap: () => _handleTap(context),
      child: Padding(
        padding: ...,
        child: Column(
          children: [
            _TitleLine(...),
            const SizedBox(height: 8),
            _MetaLine(...),
            // 新增：阅读进度条
            _ReadingProgressBar(tid: thread.tid),
          ],
        ),
      ),
    ),
  );
}

void _handleTap(BuildContext context) {
  final record = ...; // 从 provider 获取
  if (record != null && !record.isFinished) {
    // 有未完成的阅读记录，跳转到上次位置
    context.push('/thread/${thread.tid}?page=${record.lastReadPage}');
  } else {
    context.push('/thread/${thread.tid}');
  }
}
```

**进度条 Widget 设计：**

```dart
class _ReadingProgressBar extends ConsumerWidget {
  const _ReadingProgressBar({required this.tid});
  final String tid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final record = ref.watch(readingRecordProvider(tid));
    if (record == null || record.progress <= 0) {
      return const SizedBox.shrink();
    }

    final scheme = Theme.of(context).colorScheme;
    final isFinished = record.isFinished;

    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: [
          Icon(
            isFinished ? Icons.check_circle_outline : Icons.schedule,
            size: 12,
            color: isFinished
                ? scheme.onSurfaceVariant
                : scheme.primary,
          ),
          const SizedBox(width: 4),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: record.progress,
                minHeight: 3,
                backgroundColor: scheme.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation<Color>(
                  isFinished
                      ? scheme.onSurfaceVariant.withValues(alpha: 0.3)
                      : scheme.primary,
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            isFinished ? '已读' : 'P${record.lastReadPage}',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: isFinished
                  ? scheme.onSurfaceVariant
                  : scheme.primary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
```

### 6.3 阅读历史页面

**新建：`lib/screens/reading_history_screen.dart`**

功能：
- 按最后阅读时间倒序展示阅读记录
- 每条记录显示：标题、作者、版块、进度条、最后阅读时间
- 左滑删除单条记录
- AppBar 右上角"清空"按钮
- 空状态提示
- 点击跳转到对应帖子（带续读页码）

**UI 结构：**

```
┌──────────────────────────────────────┐
│ AppBar: 阅读历史        [清空]        │
├──────────────────────────────────────┤
│ ┌──────────────────────────────────┐ │
│ │ [帖子标题]                        │ │
│ │ 作者 · 版块 · 3小时前             │ │
│ │ ████████░░░░ 65%  P3/5           │ │
│ └──────────────────────────────────┘ │
│ ┌──────────────────────────────────┐ │
│ │ [帖子标题]                        │ │
│ │ 作者 · 版块 · 昨天                │ │
│ │ ████████████ 已读                 │ │
│ └──────────────────────────────────┘ │
│ ...                                  │
│                                      │
│        (空状态：暂无阅读记录)          │
└──────────────────────────────────────┘
```

### 6.4 HomeScreen 集成

**方案 A（推荐）：替换"搜索"Tab 为"历史"Tab**

```
NavigationBar:
  [论坛]  [历史]  [消息]  [我的]
```

理由：搜索功能暂未实现，阅读历史是更高优先级的功能。后续实现搜索时可合并为"发现"Tab。

**方案 B：在"我的"Tab 中添加入口**

在 ProfileScreen 中添加"阅读历史"列表项，点击跳转到独立页面。

**推荐方案 A**，因为阅读历史是高频操作，放在一级 Tab 可减少点击层级。

---

## 7. 初始化流程

### 7.1 main.dart 改动

```dart
// main.dart 中添加 Hive box 初始化

await Hive.initFlutter();
await Hive.openBox('cookies');
await Hive.openBox('settings');
await Hive.openBox('cache');
await Hive.openBox<Map>('reading_history');  // 新增
```

### 7.2 Provider 注册

在 `reading_history_provider.dart` 中声明所有 provider，无需额外注册步骤。

---

## 8. 与现有代码的集成点

| 文件 | 改动类型 | 改动内容 |
|------|---------|---------|
| `lib/main.dart` | 修改 | 添加 `Hive.openBox<Map>('reading_history')` |
| `lib/models/reading_record.dart` | **新建** | ReadingRecord 数据模型 |
| `lib/services/reading_history_service.dart` | **新建** | Hive CRUD + LRU 淘汰 |
| `lib/providers/reading_history_provider.dart` | **新建** | Riverpod providers |
| `lib/screens/thread_detail_screen.dart` | 修改 | 记录进度 + 续读提示 |
| `lib/screens/reading_history_screen.dart` | **新建** | 阅读历史列表页 |
| `lib/widgets/thread_card.dart` | 修改 | 进度指示器 + 续读跳转 |
| `lib/screens/home_screen.dart` | 修改 | 添加"历史"Tab |
| `lib/app.dart` | 修改 | 添加阅读历史路由（可选） |

---

## 9. 边界情况处理

| 场景 | 处理方式 |
|------|---------|
| 帖子标题更新 | 每次阅读时用最新标题覆盖缓存 |
| 帖子被删除 | 历史记录保留，点击时显示错误提示 |
| 翻到最后一页 | `isFinished = true`，进度显示"已读" |
| 快速切换帖子 | 每次翻页都写入，Hive 写入是同步的 |
| 存储超限 | LRU 淘汰最久未访问的记录 |
| 未登录状态 | 历史记录不受登录状态影响，本地独立存储 |
| 多设备同步 | v1.0 不支持，纯本地存储 |

---

## 10. 后续扩展（v2.0 预留）

- [ ] 搜索历史记录（标题/作者关键词）
- [ ] 按版块筛选历史
- [ ] 收藏/书签功能（独立于历史）
- [ ] 阅读统计（每日阅读量、活跃版块）
- [ ] 导出阅读数据

---

## 11. 实现顺序

```
Phase 1: 数据层
  1.1 ReadingRecord 模型
  1.2 ReadingHistoryService
  1.3 main.dart 初始化

Phase 2: Provider 层
  2.1 readingHistoryServiceProvider
  2.2 readingRecordProvider
  2.3 readingHistoryProvider

Phase 3: UI 集成
  3.1 ThreadDetailScreen 记录进度
  3.2 ThreadCard 进度指示器 + 续读跳转
  3.3 ReadingHistoryScreen 历史列表

Phase 4: 导航集成
  4.1 HomeScreen Tab 替换
  4.2 路由配置
```

---

## 12. 验收标准

- [ ] 进入帖子详情页后，阅读记录自动创建
- [ ] 翻页后，阅读记录自动更新页码和进度
- [ ] 从帖子列表再次点击已读帖子，可跳转到上次页码
- [ ] ThreadCard 显示阅读进度条（已读/未读/部分阅读）
- [ ] 阅读历史页面按时间倒序展示所有记录
- [ ] 支持删除单条记录和清空全部
- [ ] 超过 500 条时自动淘汰最旧记录
- [ ] 所有操作无需网络，纯本地完成
- [ ] `flutter analyze` 无 error/warning
