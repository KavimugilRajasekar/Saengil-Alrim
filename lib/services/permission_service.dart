import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

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
    return missing;
  }
}

enum MissingPermission { notifications, exactAlarm, batteryOptimization }
