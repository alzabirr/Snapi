package com.example.screen

import android.content.ComponentName
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.snapi/device_settings"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "openAutoStart"       -> result.success(openAutoStart())
                    "openOnePlusSettings" -> result.success(openOnePlusSettings())
                    "openBatterySettings" -> result.success(openBatterySettings())
                    "openAppDetails"      -> result.success(openAppDetails())
                    "openPowerManager"    -> result.success(openPowerManager())
                    else                  -> result.notImplemented()
                }
            }
    }

    // ─── Xiaomi / Redmi / Poco — MIUI/HyperOS Autostart ───────────────────────
    private fun openAutoStart(): Boolean {
        val intents = listOf(
            Intent().apply {
                component = ComponentName(
                    "com.miui.securitycenter",
                    "com.miui.permcenter.autostart.AutoStartManagementActivity"
                )
            },
            Intent().apply {
                component = ComponentName(
                    "com.miui.securitycenter",
                    "com.miui.permcenter.permissions.PermissionsEditorActivity"
                )
            },
            Intent().apply {
                component = ComponentName(
                    "com.miui.securitycenter",
                    "com.miui.permcenter.permissions.AppPermissionsEditorActivity"
                )
            },
            Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                data = Uri.parse("package:$packageName")
            }
        )
        return tryLaunchIntents(intents)
    }

    // ─── OnePlus — OxygenOS / HyperOS battery optimization ────────────────────
    private fun openOnePlusSettings(): Boolean {
        val intents = listOf(
            // OxygenOS 14 / OnePlus 12+ — Battery optimization list
            Intent().apply {
                component = ComponentName(
                    "com.oplus.battery",
                    "com.oplus.battery.optimize.BatteryOptimizeListActivity"
                )
            },
            // OxygenOS 13 — power manager
            Intent().apply {
                component = ComponentName(
                    "com.oplus.battery",
                    "com.oplus.powermanager.fuelgaue.PowerUsageInfoActivity"
                )
            },
            // Older OxygenOS — "Background App Management"
            Intent().apply {
                component = ComponentName(
                    "com.oneplus.security",
                    "com.oneplus.security.chainlaunch.view.ChainLaunchAppListActivity"
                )
            },
            // Standard Android battery optimization settings (all Android 6+)
            Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS),
            // Hard fallback — app detail page
            Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                data = Uri.parse("package:$packageName")
            }
        )
        return tryLaunchIntents(intents)
    }

    // ─── Samsung — Device Care / Battery ───────────────────────────────────────
    private fun openBatterySettings(): Boolean {
        val intents = mutableListOf<Intent>()

        intents.add(Intent().apply {
            component = ComponentName(
                "com.samsung.android.lool",
                "com.samsung.android.sm.battery.ui.BatteryActivity"
            )
        })
        intents.add(Intent().apply {
            component = ComponentName(
                "com.samsung.android.lool",
                "com.samsung.android.sm.ui.battery.BatteryActivity"
            )
        })
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            intents.add(Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS))
        }
        intents.add(Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
            data = Uri.parse("package:$packageName")
        })

        return tryLaunchIntents(intents)
    }

    // ─── Oppo / Realme / Vivo — ColorOS Startup Manager ───────────────────────
    private fun openAppDetails(): Boolean {
        val intents = listOf(
            Intent().apply {
                component = ComponentName(
                    "com.coloros.safecenter",
                    "com.coloros.safecenter.startupapp.StartupAppListActivity"
                )
            },
            Intent().apply {
                component = ComponentName(
                    "com.oplus.safecenter",
                    "com.oplus.safecenter.startupapp.StartupAppListActivity"
                )
            },
            Intent().apply {
                component = ComponentName(
                    "com.coloros.oppoguardelf",
                    "com.coloros.powermanager.fuelgaue.PowerUsageModelActivity"
                )
            },
            Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                data = Uri.parse("package:$packageName")
            }
        )
        return tryLaunchIntents(intents)
    }

    // ─── Huawei / Honor — Protected Apps / Startup Manager ────────────────────
    private fun openPowerManager(): Boolean {
        val intents = listOf(
            Intent().apply {
                component = ComponentName(
                    "com.huawei.systemmanager",
                    "com.huawei.systemmanager.startupmgr.ui.StartupNormalAppListActivity"
                )
            },
            Intent().apply {
                component = ComponentName(
                    "com.huawei.systemmanager",
                    "com.huawei.systemmanager.optimize.process.ProtectActivity"
                )
            },
            Intent().apply {
                component = ComponentName(
                    "com.huawei.systemmanager",
                    "com.huawei.systemmanager.appcontrol.activity.StartupAppControlActivity"
                )
            },
            Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                data = Uri.parse("package:$packageName")
            }
        )
        return tryLaunchIntents(intents)
    }

    // ─── Helper: try each intent, stop at first that works ─────────────────────
    private fun tryLaunchIntents(intents: List<Intent>): Boolean {
        for (intent in intents) {
            try {
                intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                if (intent.resolveActivity(packageManager) != null) {
                    startActivity(intent)
                    return true
                }
            } catch (_: Exception) {
                continue
            }
        }
        // Absolute last resort
        return try {
            startActivity(Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                data = Uri.parse("package:$packageName")
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            })
            true
        } catch (_: Exception) { false }
    }
}
