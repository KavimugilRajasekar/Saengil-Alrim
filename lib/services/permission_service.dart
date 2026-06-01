import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Handles runtime permission checks needed for reliable alarm delivery.
///
/// Two things must be true for alarms to fire on ALL Android devices:
///
/// 1. EXACT ALARM permission (Android 12+ / API 31+)
///    - API 21-30: always granted, nothing to do.
///    - API 31-32: granted by default at install, but user can revoke.
///    - API 33+  : USE_EXACT_ALARM is auto-granted (declared in manifest).
///                 SCHEDULE_EXACT_ALARM is denied by default — we check
///                 and redirect to Settings if needed.
///
/// 2. BATTERY OPTIMIZATION exemption
///    - Samsung, Xiaomi, Huawei, OnePlus and many other OEMs aggressively
///      kill background apps. Without this exemption the AlarmService is
///      killed and the alarm never fires.
///    - We request this via MainActivity's native channel on first launch,
///      but also expose a check here so the UI can re-prompt if needed.
class PermissionService {
  static final PermissionService _instance = PermissionService._internal();
  factory PermissionService() => _instance;
  PermissionService._internal();

  static const _channel = MethodChannel('com.example.saengil_alrim/battery');

  // ── Exact alarm permission ─────────────────────────────────────

  /// Returns true if the app can schedule exact alarms.
  /// Always true on iOS and Android < 12.
  Future<bool> hasExactAlarmPermission() async {
    if (!Platform.isAndroid) return true;
    try {
      final result = await _channel.invokeMethod<bool>('canScheduleExactAlarms');
      return result ?? true;
    } catch (e) {
      debugPrint('[Permission] canScheduleExactAlarms error: $e');
      return true; // assume granted if check fails
    }
  }

  /// Opens the system Settings page where the user can grant
  /// the SCHEDULE_EXACT_ALARM permission (Android 12+ only).
  Future<void> requestExactAlarmPermission() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('openExactAlarmSettings');
    } catch (e) {
      debugPrint('[Permission] openExactAlarmSettings error: $e');
    }
  }

  // ── Battery optimization exemption ────────────────────────────

  /// Returns true if the app is already exempt from battery optimization.
  Future<bool> isIgnoringBatteryOptimizations() async {
    if (!Platform.isAndroid) return true;
    try {
      final result = await _channel
          .invokeMethod<bool>('isIgnoringBatteryOptimizations');
      return result ?? true;
    } catch (e) {
      debugPrint('[Permission] isIgnoringBatteryOptimizations error: $e');
      return true;
    }
  }

  /// Opens the system dialog asking the user to exempt this app
  /// from battery optimization.
  Future<void> requestIgnoreBatteryOptimizations() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('requestIgnoreBatteryOptimizations');
    } catch (e) {
      debugPrint('[Permission] requestIgnoreBatteryOptimizations error: $e');
    }
  }

  /// Checks both permissions and returns a list of missing ones.
  /// Empty list = everything is granted.
  Future<List<MissingPermission>> checkAll() async {
    final missing = <MissingPermission>[];
    if (!await hasExactAlarmPermission()) {
      missing.add(MissingPermission.exactAlarm);
    }
    if (!await isIgnoringBatteryOptimizations()) {
      missing.add(MissingPermission.batteryOptimization);
    }
    return missing;
  }
}

enum MissingPermission { exactAlarm, batteryOptimization }
