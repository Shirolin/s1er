package com.stage1st.s1er

import android.content.ComponentName
import android.content.pm.PackageManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "com.stage1st.s1er/app_icon"

    /** Must stay aligned with AppIconCatalog ids / sync_app_icons aliases. */
    private val iconAliasSuffixes = linkedMapOf(
        "black" to ".IconBlack",
        "white" to ".IconWhite",
        "xb2" to ".IconXb2",
    )

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
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
