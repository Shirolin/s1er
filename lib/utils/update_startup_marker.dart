import 'update_startup_marker_stub.dart'
    if (dart.library.io) 'update_startup_marker_io.dart' as impl;

/// 覆盖更新交接用的环境变量名：旧进程据此把「已启动标记文件」路径传给
/// 新进程，新进程启动早期写入该文件表示自己成功运行。
const updateStartedMarkerEnv = 'S1ER_STARTED_MARKER';

/// 若本次启动由覆盖更新拉起（[updateStartedMarkerEnv] 已设置），
/// 在启动早期写入标记文件，让仍在等待的旧进程确认后退出。
///
/// 越早调用越好，应置于 `main()` 首行。
void reportUpdateStartedIfRequested() =>
    impl.reportUpdateStarted(updateStartedMarkerEnv);
