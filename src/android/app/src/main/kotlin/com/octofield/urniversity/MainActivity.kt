package com.octofield.urniversity

import android.content.ComponentName
import android.content.pm.PackageManager
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Carries the app style out of Flutter to the parts Android draws before
 * Flutter runs (system_design.md §3-R): the launcher icon and the system
 * splash screen.
 */
class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            val style = call.argument<String>("style")?.takeIf { it in STYLES } ?: STYLES.first()
            when (call.method) {
                "setIcon" -> {
                    setIcon(style)
                    result.success(null)
                }
                "setSplash" -> {
                    setSplash(style)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    /**
     * Enables the style's launcher alias and disables the rest. The new one is
     * enabled first so there is never a moment with no launcher entry at all.
     * DONT_KILL_APP, or the system restarts the app under the user.
     */
    private fun setIcon(style: String) {
        val pm = packageManager
        val target = alias(style)
        if (isEnabled(pm, style)) return
        pm.setComponentEnabledSetting(
            target,
            PackageManager.COMPONENT_ENABLED_STATE_ENABLED,
            PackageManager.DONT_KILL_APP,
        )
        for (other in STYLES) {
            if (other == style) continue
            pm.setComponentEnabledSetting(
                alias(other),
                PackageManager.COMPONENT_ENABLED_STATE_DISABLED,
                PackageManager.DONT_KILL_APP,
            )
        }
    }

    private fun isEnabled(pm: PackageManager, style: String): Boolean =
        when (pm.getComponentEnabledSetting(alias(style))) {
            PackageManager.COMPONENT_ENABLED_STATE_ENABLED -> true
            // Untouched: whatever the manifest says, which is linen only
            PackageManager.COMPONENT_ENABLED_STATE_DEFAULT -> style == STYLES.first()
            else -> false
        }

    private fun alias(style: String) =
        ComponentName(this, "com.octofield.urniversity.Style${style.replaceFirstChar { it.uppercase() }}")

    /**
     * The splash the NEXT launch shows. Android 13 added a way to choose it at
     * run time, and remembers the choice; older versions keep the linen one
     */
    private fun setSplash(style: String) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) return
        splashScreen.setSplashScreenTheme(
            when (style) {
                "modern" -> R.style.LaunchTheme_Modern
                "midnight" -> R.style.LaunchTheme_Midnight
                "sage" -> R.style.LaunchTheme_Sage
                "ocean" -> R.style.LaunchTheme_Ocean
                "sakura" -> R.style.LaunchTheme_Sakura
                "mono" -> R.style.LaunchTheme_Mono
                else -> R.style.LaunchTheme
            },
        )
    }

    companion object {
        private const val CHANNEL = "urniversity/style"

        // Same order and names as AppStyle in lib/core/theme/app_styles.dart
        private val STYLES = listOf("linen", "modern", "midnight", "sage", "ocean", "sakura", "mono")
    }
}
