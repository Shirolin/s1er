package com.stage1st.s1er

import android.content.ComponentName
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private val iconChannelName = "com.stage1st.s1er/app_icon"
    private val apkInstallerChannelName = "com.stage1st.s1er/apk_installer"

    /** Must stay aligned with AppIconCatalog ids / sync_app_icons aliases. */
    private val iconAliasSuffixes = linkedMapOf(
        "black" to ".IconBlack",
        "white" to ".IconWhite",
        "xb2" to ".IconXb2",
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
                    else -> result.notImplemented()
                }
            }
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
