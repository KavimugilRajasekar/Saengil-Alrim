import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Handles runtime permission checks needed for reliable alarm delivery.
///
/// Three things must be true for alarms to fire and show on ALL Android devices:
///
/// 1. POST_NOTIFICATIONS (Android 13+ / API 33+)
///    - Without this the full-screen notification is silently suppressed.
///    - Must be requested at runtime — declaring in manifest is not enough.
///
/// 2. EXACT ALARM permission (Android 12+ / API 31+)
///    - API 21-30: always granted.
///    - API 31-32: granted by default at install, user can revoke.
///    - API 33+  : USE_EXACT_ALARM is auto-granted (declared in manifest).
///
/// 3. BATTERY OPTIMIZATION exemption
///    - Samsung, Xiaomi, Huawei, OnePlus aggressively kill background apps.
///    - Without this the AlarmService is killed before the alarm fires.
///
/// 4. OEM-SPECIFIC BATTERY / AUTOSTART settings (Xiaomi, Samsung, Huawei…)
///    - Standard battery optimization exemption is not enough on many OEMs.
///    - We detect the manufacturer and guide users to the correct settings.
class PermissionService {
  static final PermissionService _instance = PermissionService._internal();
  factory PermissionService() => _instance;
  PermissionService._internal();

  static const _channel = MethodChannel('com.example.saengil_alrim/battery');

  // ── POST_NOTIFICATIONS (Android 13+) ──────────────────────────

  /// Returns true if the app has notification permission.
  /// Always true on Android < 13 and iOS.
  Future<bool> hasNotificationPermission() async {
    if (!Platform.isAndroid) return true;
    try {
      final result = await _channel.invokeMethod<bool>('hasNotificationPermission');
      return result ?? true;
    } catch (e) {
      debugPrint('[Permission] hasNotificationPermission error: $e');
      return true;
    }
  }

  /// Shows the system dialog asking the user to grant POST_NOTIFICATIONS.
  Future<void> requestNotificationPermission() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('requestNotificationPermission');
    } catch (e) {
      debugPrint('[Permission] requestNotificationPermission error: $e');
    }
  }

  // ── Exact alarm permission ─────────────────────────────────────

  Future<bool> hasExactAlarmPermission() async {
    if (!Platform.isAndroid) return true;
    try {
      final result = await _channel.invokeMethod<bool>('canScheduleExactAlarms');
      return result ?? true;
    } catch (e) {
      debugPrint('[Permission] canScheduleExactAlarms error: $e');
      return true;
    }
  }

  Future<void> requestExactAlarmPermission() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('openExactAlarmSettings');
    } catch (e) {
      debugPrint('[Permission] openExactAlarmSettings error: $e');
    }
  }

  // ── Battery optimization exemption ────────────────────────────

  Future<bool> isIgnoringBatteryOptimizations() async {
    if (!Platform.isAndroid) return true;
    try {
      final result =
          await _channel.invokeMethod<bool>('isIgnoringBatteryOptimizations');
      return result ?? true;
    } catch (e) {
      debugPrint('[Permission] isIgnoringBatteryOptimizations error: $e');
      return true;
    }
  }

  Future<void> requestIgnoreBatteryOptimizations() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('requestIgnoreBatteryOptimizations');
    } catch (e) {
      debugPrint('[Permission] requestIgnoreBatteryOptimizations error: $e');
    }
  }

  // ── OEM-specific battery / autostart settings ──────────────────
  //
  // Samsung, Xiaomi (MIUI), Huawei (EMUI), Oppo, Vivo, OnePlus all have
  // proprietary "autostart" or "background app" managers that can silently
  // kill the AlarmService even when battery optimisation is disabled.
  // This method opens the relevant OEM screen, falling back to the standard
  // battery optimization screen for unknown manufacturers.

  /// Returns the device manufacturer string (lowercase) from the native side.
  Future<String> getManufacturer() async {
    if (!Platform.isAndroid) return '';
    try {
      final result = await _channel.invokeMethod<String>('getManufacturer');
      return result?.toLowerCase() ?? '';
    } catch (e) {
      debugPrint('[Permission] getManufacturer error: $e');
      return '';
    }
  }

  /// Returns true if this device is from an OEM known to have extra
  /// battery-killing behaviour AND the user has not yet dismissed the banner.
  Future<bool> needsOemBatterySettings() async {
    if (!Platform.isAndroid) return false;
    // If the user already dismissed the banner, don't show it again.
    if (await isOemBannerDismissed()) return false;
    final m = await getManufacturer();
    return m.contains('xiaomi') ||
        m.contains('huawei') ||
        m.contains('honor') ||
        m.contains('samsung') ||
        m.contains('oppo') ||
        m.contains('vivo') ||
        m.contains('oneplus') ||
        m.contains('realme');
  }

  /// Returns a user-friendly label for the OEM settings screen,
  /// e.g. "Autostart" for Xiaomi, "Battery" for Samsung.
  Future<String> oemBatterySettingsLabel() async {
    final m = await getManufacturer();
    if (m.contains('xiaomi')) return 'MIUI Autostart';
    if (m.contains('huawei') || m.contains('honor')) return 'App Launch Manager';
    if (m.contains('samsung')) return 'Battery (Background usage)';
    if (m.contains('oppo') || m.contains('realme')) return 'Startup Manager';
    if (m.contains('vivo')) return 'Background App Refresh';
    if (m.contains('oneplus')) return 'Battery Optimization';
    return 'Battery Optimization';
  }

  /// Opens the OEM-specific autostart / battery screen for the current device.
  /// Always returns after attempting to launch (errors are handled internally).
  Future<void> openOemBatterySettings() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('openOemBatterySettings');
    } catch (e) {
      debugPrint('[Permission] openOemBatterySettings error: $e');
    }
  }

  // ── OEM banner dismiss (persisted) ────────────────────────────
  //
  // Since Android has no API to read OEM autostart state, we give the user
  // an explicit dismiss button. The dismissal is stored in SharedPreferences
  // so the banner stays gone across restarts.

  static const _oemDismissedKey = 'oem_battery_banner_dismissed';

  Future<bool> isOemBannerDismissed() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_oemDismissedKey) ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<void> dismissOemBanner() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_oemDismissedKey, true);
    } catch (_) {}
  }

  // ── Check all ─────────────────────────────────────────────────

  /// Returns a list of missing permissions. Empty = all granted.
  Future<List<MissingPermission>> checkAll() async {
    final missing = <MissingPermission>[];
    if (!await hasNotificationPermission()) {
      missing.add(MissingPermission.notifications);
    }
    if (!await hasExactAlarmPermission()) {
      missing.add(MissingPermission.exactAlarm);
    }
    if (!await isIgnoringBatteryOptimizations()) {
      missing.add(MissingPermission.batteryOptimization);
    }
    // OEM-specific check: we can't detect the actual setting programmatically,
    // so we flag the OEM warning whenever the device is from a known OEM.
    if (await needsOemBatterySettings()) {
      missing.add(MissingPermission.oemBatterySettings);
    }
    return missing;
  }
}

enum MissingPermission {
  notifications,
  exactAlarm,
  batteryOptimization,
  /// Present on Xiaomi, Samsung, Huawei, Oppo, Vivo, OnePlus etc.
  /// These OEMs require manual steps in their proprietary settings UI
  /// that cannot be detected or requested via the standard Android API.
  oemBatterySettings,
}
