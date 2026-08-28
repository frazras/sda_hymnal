package com.ionicframework.sdanewandoldhymnal816673

import android.content.ComponentName
import android.content.pm.PackageManager
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class HymnalActivity : FlutterActivity() {
    private var iconChannel: MethodChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
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
            // Never leave the app without an enabled launcher entry, even
            // during the two calls required on Android 12 and earlier.
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
