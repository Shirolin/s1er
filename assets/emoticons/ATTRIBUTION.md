# 麻将脸表情资源说明与致谢

本目录下的表情图片（`face2017/`、`carton2017/` 等）**不是** S1er 原创。

## 来源

维护入库时，优先从社区整理仓库的 **GitHub Release** 获取（`without prefixs & descriptions` 目录，与 Discuz / 客户端编号一致）：

- 仓库：[kawaiidora/s1emoticon](https://github.com/kawaiidora/s1emoticon)（S1 麻将脸库存）
- 讨论帖：[https://bbs.saraba1st.com/2b/thread-1987269-1-1.html](https://bbs.saraba1st.com/2b/thread-1987269-1-1.html)
- 本仓库当前使用的 Release 标签见 `scripts/download_emoticons.dart` 中的 `defaultReleaseTag`

表情创作与论坛托管归 Stage1st 社区及原作者；`s1emoticon` 负责整理与打包。

## 许可状态（重要）

截至声明撰写时，[kawaiidora/s1emoticon](https://github.com/kawaiidora/s1emoticon) **未附带 SPDX / LICENSE 文件**（GitHub 显示无许可证）。

因此：

- **不能**假定这些图片可按 MIT/Apache/GPL 等条款再授权；
- S1er 仅在第三方客户端中**原样再分发**已公开托管的表情资源，用于与论坛帖子中的 `[f:001]` 等实体一致显示；
- 权利仍属于原作者与 Stage1st 相关权利人；若权利人要求下架或变更使用方式，维护者将配合处理。

运行时若本地 asset 缺失，客户端可能回退请求论坛静态资源 `https://static.stage1st.com/image/smiley/`（单张显示用，不是批量灌库脚本）。

## 维护

维护者增量更新（命令与参数见脚本头注释；脚本**无** `--help`）：

```bash
dart run scripts/download_emoticons.dart              # 缺文件时从 Release zip 补齐
dart run scripts/download_emoticons.dart --dry-run    # 只统计
dart run scripts/download_emoticons.dart --write-list # 按 packs.json 重生 download_list.txt
dart run scripts/download_emoticons.dart --tag=r5.13  # 指定 Release tag
```

详见 [开发指南](../../docs/development.md)。请勿将下载脚本放入 CI，勿对论坛 CDN 做全量扫描。
