import 'package:flutter/material.dart';

import 's1_confirm_dialog.dart';

Future<bool> confirmHideForum(BuildContext context) {
  return showS1ConfirmDialog(
    context,
    title: '屏蔽版块',
    content: '屏蔽后该版块将从首页隐藏，可在设置中恢复。不影响收藏与直接打开。',
    confirmLabel: '屏蔽',
    destructive: true,
  );
}
