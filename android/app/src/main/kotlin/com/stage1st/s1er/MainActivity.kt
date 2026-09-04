package com.stage1st.s1er

import android.app.DownloadManager
import android.content.BroadcastReceiver
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.Settings
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private val iconChannelName = "com.stage1st.s1er/app_icon"
    private val apkInstallerChannelName = "com.stage1st.s1er/apk_installer"
    private val pendingApkDownloads = mutableMapOf<Long, File>()
    private var downloadReceiver: BroadcastReceiver? = null

    /** Must stay aligned with UpdateCheckService.allowedDownloadHosts (Dart).
     *  增删 host 后须跑 update_check_service_test 并手动核对 Kotlin 列表。 */
    private val allowedDownloadHosts = setOf(
        "github.com",
        "www.github.com",
        "raw.githubusercontent.com",
        "objects.githubusercontent.com",
        "release-assets.githubusercontent.com",
        "cdn.jsdelivr.net",
        "play.google.com",
    )

    /** Must stay aligned with AppIconCatalog ids / sync_app_icons aliases. */
    private val iconAliasSuffixes = linkedMapOf(
        "black" to ".IconBlack",
        "white" to ".IconWhite",
        "xb2" to ".IconXb2",
        "md" to ".IconMd",
    )

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, iconChannelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getIcon" -> result.success(currentIconId())
                    "setIcon" -> {
                        val id = call.argument<String>("id")
                        if (id.isNullOrBlank() || !iconAliasSuffixes.containsKey(id)) {
                            result.error("invalid_id", "Unknown icon id: $id", null)
                            return@setMethodCallHandler
                        }
                        try {
                            setIcon(id)
                            result.success(null)
                        } catch (e: Exception) {
                            result.error("set_failed", e.message, null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, apkInstallerChannelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "canInstallPackages" -> result.success(canInstallPackages())
                    "openInstallPermissionSettings" -> {
                        try {
                            openInstallPermissionSettings()
                            result.success(null)
                        } catch (e: Exception) {
                            result.error("settings_failed", e.message, null)
                        }
                    }
                    "installApk" -> {
                        val path = call.argument<String>("path")
                        if (path.isNullOrBlank()) {
                            result.error("invalid_path", "APK path is required", null)
                            return@setMethodCallHandler
                        }
                        try {
                            installApk(path)
                            result.success(null)
                        } catch (e: Exception) {
                            result.error("install_failed", e.message, null)
                        }
                    }
                    "enqueueApkDownload" -> {
                        val url = call.argument<String>("url")
                        val fileName = call.argument<String>("fileName")
                        if (url.isNullOrBlank() || fileName.isNullOrBlank()) {
                            result.error(
                                "invalid_args",
                                "url and fileName are required",
                                null,
                            )
                            return@setMethodCallHandler
                        }
                        try {
                            enqueueApkDownload(url, fileName)
                            result.success(null)
                        } catch (e: Exception) {
                            result.error("enqueue_failed", e.message, null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    override fun onDestroy() {
        downloadReceiver?.let { receiver ->
            try {
                unregisterReceiver(receiver)
            } catch (_: Exception) {
                // already unregistered
            }
        }
        downloadReceiver = null
        pendingApkDownloads.clear()
        super.onDestroy()
    }

    private fun canInstallPackages(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            packageManager.canRequestPackageInstalls()
        } else {
            true
        }
    }

    private fun openInstallPermissionSettings() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val intent = Intent(
                Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                Uri.parse("package:$packageName"),
            )
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            startActivity(intent)
        }
    }

    private fun installApk(path: String) {
        val file = File(path)
        if (!file.exists() || !file.isFile) {
            throw IllegalArgumentException("APK not found: $path")
        }
        val authority = "$packageName.fileprovider"
        val uri = FileProvider.getUriForFile(this, authority, file)
        val intent = Intent(Intent.ACTION_VIEW).apply {
            setDataAndType(uri, "application/vnd.android.package-archive")
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
        startActivity(intent)
    }

    private fun enqueueApkDownload(url: String, fileName: String) {
        if (!url.startsWith("https://", ignoreCase = true)) {
            throw IllegalArgumentException("Only https downloads are allowed")
        }
        if (!isAllowedDownloadHost(url)) {
            throw IllegalArgumentException("Download host not allowed")
        }
        val safeName = fileName.replace(Regex("[^\\w.\\-+]"), "_").ifEmpty {
            "s1er-update.apk"
        }
        ensureDownloadReceiver()
        val destDir = getExternalFilesDir(Environment.DIRECTORY_DOWNLOADS)
            ?: throw IllegalStateException("External files dir unavailable")
        val dest = File(destDir, safeName)
        if (dest.exists()) {
            dest.delete()
        }
        val request = DownloadManager.Request(Uri.parse(url)).apply {
            setTitle(safeName)
            setDescription("S1er 更新")
            setMimeType("application/vnd.android.package-archive")
            setNotificationVisibility(
                DownloadManager.Request.VISIBILITY_VISIBLE_NOTIFY_COMPLETED,
            )
            setAllowedOverMetered(true)
            setAllowedOverRoaming(true)
            addRequestHeader("Accept", "application/octet-stream")
            addRequestHeader("Accept-Encoding", "identity")
            addRequestHeader(
                "User-Agent",
                "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 " +
                    "(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
            )
            setDestinationInExternalFilesDir(
                this@MainActivity,
                Environment.DIRECTORY_DOWNLOADS,
                safeName,
            )
        }
        val dm = getSystemService(DOWNLOAD_SERVICE) as DownloadManager
        val id = dm.enqueue(request)
        pendingApkDownloads[id] = dest
    }

    private fun ensureDownloadReceiver() {
        if (downloadReceiver != null) return
        val receiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context?, intent: Intent?) {
                if (intent?.action != DownloadManager.ACTION_DOWNLOAD_COMPLETE) return
                val id = intent.getLongExtra(DownloadManager.EXTRA_DOWNLOAD_ID, -1L)
                val dest = pendingApkDownloads.remove(id) ?: return
                val dm = getSystemService(DOWNLOAD_SERVICE) as DownloadManager
                val cursor = dm.query(DownloadManager.Query().setFilterById(id))
                cursor.use {
                    if (!it.moveToFirst()) return
                    val statusIndex = it.getColumnIndex(DownloadManager.COLUMN_STATUS)
                    if (statusIndex < 0) return
                    val status = it.getInt(statusIndex)
                    if (status != DownloadManager.STATUS_SUCCESSFUL) return
                }
                try {
                    installApk(dest.absolutePath)
                } catch (_: Exception) {
                    // 通知栏仍可点开安装包
                }
            }
        }
        downloadReceiver = receiver
        val filter = IntentFilter(DownloadManager.ACTION_DOWNLOAD_COMPLETE)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(receiver, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            @Suppress("UnspecifiedRegisterReceiverFlag")
            registerReceiver(receiver, filter)
        }
    }

    private fun isAllowedDownloadHost(url: String): Boolean {
        val uri = Uri.parse(url.trim())
        if (uri.scheme?.lowercase() != "https") return false
        if (!uri.userInfo.isNullOrEmpty()) return false
        val host = uri.host?.lowercase() ?: return false
        if (uri.port != -1 && uri.port != 443) return false
        return host in allowedDownloadHosts
    }

    /** ComponentName(Context, String) does not expand leading '.' — use FQCN. */
    private fun aliasComponent(suffix: String): ComponentName {
        val className = if (suffix.startsWith('.')) {
            "$packageName$suffix"
        } else {
            suffix
        }
        return ComponentName(packageName, className)
    }

    private fun currentIconId(): String {
        val pm = packageManager
        for ((id, suffix) in iconAliasSuffixes) {
            val state = pm.getComponentEnabledSetting(aliasComponent(suffix))
            if (state == PackageManager.COMPONENT_ENABLED_STATE_ENABLED) {
                return id
            }
        }
        return "black"
    }

    private fun setIcon(id: String) {
        val pm = packageManager
        // Enable the target first so at least one LAUNCHER alias stays active.
        val targetSuffix = iconAliasSuffixes[id]!!
        pm.setComponentEnabledSetting(
            aliasComponent(targetSuffix),
            PackageManager.COMPONENT_ENABLED_STATE_ENABLED,
            PackageManager.DONT_KILL_APP,
        )
        for ((aliasId, suffix) in iconAliasSuffixes) {
            if (aliasId == id) continue
            pm.setComponentEnabledSetting(
                aliasComponent(suffix),
                PackageManager.COMPONENT_ENABLED_STATE_DISABLED,
                PackageManager.DONT_KILL_APP,
            )
        }
    }
}
