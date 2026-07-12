import 'package:flutter/material.dart';

import 's1_confirm_dialog.dart';

Future<bool> confirmUnfavorite(BuildContext context) {
  return showS1ConfirmDialog(
    context,
    title: '取消收藏',
    content: '确定要取消收藏吗？',
    confirmLabel: '取消收藏',
    destructive: true,
  );
}
