package com.ionicframework.sdanewandoldhymnal816673

import android.content.ComponentName
import android.content.pm.PackageManager
import android.os.Build
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class HymnalActivity : AudioServiceActivity() {
    private var iconChannel: MethodChannel? = null
    private var analyticsChannel: MethodChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        analyticsChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "sdahymnal/analytics_storage")
        analyticsChannel?.setMethodCallHandler { call, result ->
            if (call.method == "directory") {
                val directory = java.io.File(noBackupFilesDir, "analytics")
                if (directory.exists() || directory.mkdirs()) result.success(directory.absolutePath)
                else result.error("STORAGE", "Analytics storage unavailable", null)
            } else result.notImplemented()
        }
        iconChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "sdahymnal/app_icon")
        iconChannel?.setMethodCallHandler { call, result ->
            if (call.method != "setDesign") {
                result.notImplemented()
            } else if (call.arguments != "classic" && call.arguments != "modern") {
                result.error("INVALID_DESIGN", "Expected modern or classic", null)
            } else {
                try {
                    setClassicIcon(call.arguments == "classic")
                    result.success(null)
                } catch (error: Exception) {
                    result.error("ICON_CHANGE_FAILED", error.localizedMessage, null)
                }
            }
        }
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        analyticsChannel?.setMethodCallHandler(null)
        analyticsChannel = null
        iconChannel?.setMethodCallHandler(null)
        iconChannel = null
        super.cleanUpFlutterEngine(flutterEngine)
    }

    private fun setClassicIcon(classic: Boolean) {
        val modernIcon = ComponentName(this, "$packageName.MainActivity")
        val classicIcon = ComponentName(this, "$packageName.ClassicIcon")
        val enabled = PackageManager.COMPONENT_ENABLED_STATE_ENABLED
        val disabled = PackageManager.COMPONENT_ENABLED_STATE_DISABLED
        val default = PackageManager.COMPONENT_ENABLED_STATE_DEFAULT
        val flags = PackageManager.DONT_KILL_APP
        val oldModern = packageManager.getComponentEnabledSetting(modernIcon)
        val oldClassic = packageManager.getComponentEnabledSetting(classicIcon)
        val modernEnabled = oldModern == enabled || oldModern == default
        val classicEnabled = oldClassic == enabled
        if (classicEnabled == classic && modernEnabled == !classic) return

        val selected = if (classic) classicIcon else modernIcon
        val other = if (classic) modernIcon else classicIcon
        if (Build.VERSION.SDK_INT >= 33) {
            packageManager.setComponentEnabledSettings(listOf(
                PackageManager.ComponentEnabledSetting(selected, enabled, flags),
                PackageManager.ComponentEnabledSetting(other, disabled, flags),
            ))
        } else {
            // Keep a launcher entry enabled throughout the switch.
            try {
                packageManager.setComponentEnabledSetting(selected, enabled, flags)
                packageManager.setComponentEnabledSetting(other, disabled, flags)
            } catch (error: Exception) {
                runCatching { packageManager.setComponentEnabledSetting(modernIcon, oldModern, flags) }
                runCatching { packageManager.setComponentEnabledSetting(classicIcon, oldClassic, flags) }
                throw error
            }
        }
    }
}
