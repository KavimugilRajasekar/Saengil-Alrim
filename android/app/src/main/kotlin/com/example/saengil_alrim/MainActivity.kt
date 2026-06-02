package com.example.saengil_alrim

import android.Manifest
import android.app.AlarmManager
import android.app.KeyguardManager
import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.PowerManager
import android.provider.Settings
import android.view.WindowManager
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val CHANNEL = "com.example.saengil_alrim/battery"
    private val NOTIFICATION_PERMISSION_REQUEST_CODE = 1001

    // Holds the alarm payload from the launch/tap intent until Flutter reads it.
    private var pendingAlarmPayload: String? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {

                    // ── Notification permission (Android 13+) ─────
                    "hasNotificationPermission" ->
                        result.success(hasNotificationPermission())

                    "requestNotificationPermission" -> {
                        requestNotificationPermission()
                        result.success(null)
                    }

                    // ── Battery optimization ──────────────────────
                    "isIgnoringBatteryOptimizations" ->
                        result.success(isIgnoringBatteryOptimizations())

                    "requestIgnoreBatteryOptimizations" -> {
                        requestIgnoreBatteryOptimizations()
                        result.success(null)
                    }

                    // ── Exact alarm permission (API 31+) ──────────
                    "canScheduleExactAlarms" ->
                        result.success(canScheduleExactAlarms())

                    "openExactAlarmSettings" -> {
                        openExactAlarmSettings()
                        result.success(null)
                    }

                    // ── Notification tap payload ───────────────────
                    // Flutter calls this after init to check if the app was
                    // launched by tapping an alarm notification (unlocked device,
                    // app killed). Returns the birthday ID string or null.
                    "getNotificationLaunchPayload" -> {
                        result.success(pendingAlarmPayload)
                        pendingAlarmPayload = null // consume once
                    }

                    // ── Device locked state ───────────────────────
                    // Flutter calls this to check if the keyguard is currently
                    // locked so it can defer the ring UI until the user unlocks.
                    "isDeviceLocked" -> {
                        val km = getSystemService(Context.KEYGUARD_SERVICE) as KeyguardManager
                        result.success(km.isKeyguardLocked)
                    }

                    // ── OEM manufacturer (for OEM-specific battery tips) ──
                    "getManufacturer" ->
                        result.success(Build.MANUFACTURER.lowercase())

                    // ── Open OEM-specific battery/autostart settings ──────
                    "openOemBatterySettings" -> {
                        openOemBatterySettings()
                        result.success(null)
                    }

                    else -> result.notImplemented()
                }
            }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // Capture payload from the intent that launched this activity
        // (e.g. user tapped the alarm notification while device was unlocked).
        extractAlarmPayload(intent)

        // Request battery optimization exemption on first launch.
        if (!isIgnoringBatteryOptimizations()) {
            requestIgnoreBatteryOptimizations()
        }

        // Request POST_NOTIFICATIONS on Android 13+ — without this the
        // full-screen alarm notification is silently suppressed.
        if (!hasNotificationPermission()) {
            requestNotificationPermission()
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        // Capture payload for the new intent (app running, notification tapped).
        extractAlarmPayload(intent)
    }

    // ── Extract alarm payload from intent extras ──────────────────
    // The alarm package puts the payload in the "payload" extra of the
    // PendingIntent it creates for the notification tap action.
    private fun extractAlarmPayload(intent: Intent?) {
        if (intent == null) return
        val payload = intent.getStringExtra("payload")
            ?: intent.getStringExtra("notification_payload")
        if (!payload.isNullOrBlank()) {
            pendingAlarmPayload = payload
        }
    }

    // ── Notification permission ───────────────────────────────────

    private fun hasNotificationPermission(): Boolean {
        // Below API 33 notifications are always allowed
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) return true
        return ContextCompat.checkSelfPermission(
            this,
            Manifest.permission.POST_NOTIFICATIONS
        ) == PackageManager.PERMISSION_GRANTED
    }

    private fun requestNotificationPermission() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) return
        if (hasNotificationPermission()) return
        ActivityCompat.requestPermissions(
            this,
            arrayOf(Manifest.permission.POST_NOTIFICATIONS),
            NOTIFICATION_PERMISSION_REQUEST_CODE
        )
    }

    // ── Battery optimization ──────────────────────────────────────

    private fun isIgnoringBatteryOptimizations(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return true
        val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
        return pm.isIgnoringBatteryOptimizations(packageName)
    }

    private fun requestIgnoreBatteryOptimizations() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return
        try {
            startActivity(
                Intent(
                    Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS,
                    Uri.parse("package:$packageName")
                )
            )
        } catch (e: Exception) {
            try {
                startActivity(Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS))
            } catch (_: Exception) {}
        }
    }

    // ── Exact alarm permission ────────────────────────────────────

    private fun canScheduleExactAlarms(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) return true
        val am = getSystemService(Context.ALARM_SERVICE) as AlarmManager
        return am.canScheduleExactAlarms()
    }

    private fun openExactAlarmSettings() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) return
        try {
            startActivity(
                Intent(
                    Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM,
                    Uri.parse("package:$packageName")
                )
            )
        } catch (e: Exception) {
            try {
                startActivity(
                    Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                        data = Uri.parse("package:$packageName")
                    }
                )
            } catch (_: Exception) {}
        }
    }

    // ── OEM-specific battery / autostart settings ─────────────────

    private fun openOemBatterySettings() {
        val manufacturer = Build.MANUFACTURER.lowercase()
        val intent: Intent? = when {
            manufacturer.contains("xiaomi") -> runCatching {
                Intent("miui.intent.action.APP_PERM_EDITOR").apply {
                    setClassName(
                        "com.miui.securitycenter",
                        "com.miui.permcenter.autostart.AutoStartManagementActivity"
                    )
                }
            }.getOrNull()
            manufacturer.contains("huawei") || manufacturer.contains("honor") ->
                runCatching {
                    Intent().apply {
                        setClassName(
                            "com.huawei.systemmanager",
                            "com.huawei.systemmanager.startupmgr.ui.StartupNormalAppListActivity"
                        )
                    }
                }.getOrNull()
            manufacturer.contains("samsung") -> runCatching {
                Intent().apply {
                    component = android.content.ComponentName(
                        "com.samsung.android.lool",
                        "com.samsung.android.sm.battery.ui.BatteryActivity"
                    )
                }
            }.getOrNull()
            manufacturer.contains("oppo") -> runCatching {
                Intent().apply {
                    setClassName(
                        "com.coloros.safecenter",
                        "com.coloros.safecenter.permission.startup.FakeActivity"
                    )
                }
            }.getOrNull()
            manufacturer.contains("vivo") -> runCatching {
                Intent().apply {
                    setClassName(
                        "com.vivo.permissionmanager",
                        "com.vivo.permissionmanager.activity.BgStartUpManagerActivity"
                    )
                }
            }.getOrNull()
            manufacturer.contains("oneplus") -> runCatching {
                Intent().apply {
                    setClassName(
                        "com.oneplus.security",
                        "com.oneplus.security.chainlaunch.view.ChainLaunchAppListActivity"
                    )
                }
            }.getOrNull()
            else -> null
        }

        try {
            if (intent != null) {
                startActivity(intent)
                return
            }
        } catch (_: Exception) {}

        // Fallback: standard battery optimization settings
        try {
            startActivity(
                Intent(
                    Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS,
                    Uri.parse("package:$packageName")
                )
            )
        } catch (_: Exception) {
            try {
                startActivity(Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS))
            } catch (_: Exception) {}
        }
    }
}
