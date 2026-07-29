/// PC 桌面端分享与图片保存模式。
enum ShareSaveMode {
  /// 自动保存到指定的固定目录（若未设置或不可用则降级系统图片文件夹）。
  autoDir,

  /// 每次保存时弹出系统“另存为”对话框选择保存文件位置。
  promptSaveAs,
}
