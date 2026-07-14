# 交互与分层约束

- 点击区最小修复：优先复用现有可点击容器补齐命中区，不改可见尺寸、间距、圆角、行高；允许通过约 40dp 的“视觉零改动”点击面补齐可用性。
- 分层约束：`Screen/Widget -> Provider/Notifier -> Service -> HTTP` 单向流；`screens/`、`widgets/` 禁止直读 `httpClientProvider`、禁止直接调 `ApiService` 做网络动作。
- 主题策略：仅保留 `ColorScheme.fromSeed` 的浅色 / 深色 / 手动种子色，不再维护动态取色链路。
