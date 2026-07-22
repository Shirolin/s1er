import 'package:flutter/widgets.dart';

import 'compose_img_tags.dart';

/// Compose 正文展示用字数（字素长度）。
///
/// 编辑态去掉 `⟦图N⟧` 占位，避免占位符虚增字数。
int composeMessageCharCount(
  String text, {
  required bool stripMediaPlaceholders,
}) {
  final source =
      stripMediaPlaceholders ? stripComposeMediaPlaceholders(text) : text;
  return Characters(source).length;
}
