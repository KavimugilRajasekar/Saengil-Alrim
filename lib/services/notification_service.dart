import 'dart:io';

import 'package:alarm/alarm.dart';
import 'package:flutter/foundation.dart';

import 'birthday_service.dart';

/// Handles scheduling and cancelling birthday alarms using the
/// [alarm] package, which provides foreground-service audio playback.
///
/// Audio paths arriving here are already resolved to internal
/// storage relative paths (e.g. "alarm_audio/dday_123.mp3") by
/// [BirthdayProvider._resolveRingtonePaths] before saving.
///
/// KEY SETTINGS:
/// - androidFullScreenIntent = true         → required for the AlarmService
///   to post a high-priority notification and start audio reliably on all
///   Android versions. The Dart layer (main.dart) controls whether the ring
///   screen appears immediately or is deferred until the device is unlocked.
/// - androidStopAlarmOnTermination = false  → alarm keeps ringing even when
///   the user swipes the app away from recents.
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  // ── Init ──────────────────────────────────────────────────────
  Future<void> init() async {
    await Alarm.init();
  }

  // ── ID helpers ────────────────────────────────────────────────
  // IDs must be positive, non-zero, fit in signed 32-bit int.
  // D-Day  → even numbers ≥ 2
  // Advance → odd numbers ≥ 3

  int _dDayId(String friendId) {
    final h = friendId.hashCode.abs() % 1000000;
    final id = (h * 2) + 2;
    return id == 0 ? 2 : id;
  }

  int _advanceId(String friendId) {
    final h = friendId.hashCode.abs() % 1000000;
    return (h * 2) + 3;
  }

  // ── Schedule ──────────────────────────────────────────────────
  Future<void> scheduleBirthdayAlarms(FriendBirthday birthday) async {
    await scheduleBirthdayAlarmsAfter(birthday, firedAlarmId: null);
  }

  /// Reschedules both alarms for [birthday] to their next future occurrence.
  ///
  /// [firedAlarmId] — the alarm ID that just rang and was dismissed.
  ///   • If it matches the D-Day alarm ID  → D-Day rolls to next year;
  ///     advance alarm also recalculates from next year's D-Day.
  ///   • If it matches the advance alarm ID → advance rolls past today;
  ///     D-Day stays this year if it hasn't fired yet.
  ///   • null (initial scheduling / edit) → both use DateTime.now() as
  ///     reference, picking the next future occurrence naturally.
  Future<void> scheduleBirthdayAlarmsAfter(
    FriendBirthday birthday, {
    required int? firedAlarmId,
  }) async {
    await cancelBirthdayAlarms(birthday.id);

    final now = DateTime.now();

    // When the D-Day alarm just fired we need to push the reference past
    // today's birthday time so _nextOccurrence rolls to next year.
    // For the advance alarm firing we only need to push past right now,
    // which DateTime.now() already satisfies.
    final dDayRef = (firedAlarmId == _dDayId(birthday.id))
        ? now.add(const Duration(minutes: 2))
        : now;

    // ── D-Day alarm ──────────────────────────────────────────────
    if (birthday.enableDDayAlarm && birthday.dDayRingtonePath != null) {
      final t = _parseTime(birthday.dDayAlarmTimeStr);
      final fireAt = _nextOccurrence(
        month: birthday.month,
        day: birthday.day,
        hour: t.hour,
        minute: t.minute,
        now: dDayRef,
      );

      final audioPath = _validatePath(birthday.dDayRingtonePath!);
      if (audioPath != null) {
        try {
          final success = await Alarm.set(
            alarmSettings: AlarmSettings(
              id: _dDayId(birthday.id),
              dateTime: fireAt,
              assetAudioPath: audioPath,
              loopAudio: true,
              vibrate: true,
              // androidFullScreenIntent: true is required for the AlarmService
              // to post a high-priority notification and start audio reliably
              // on all Android versions — including when the app is open.
              // The Dart layer (main.dart) decides whether to show the ring
              // screen immediately or defer it until the device is unlocked.
              androidFullScreenIntent: true,
              // Keep ringing even when the user swipes the app away from recents.
              androidStopAlarmOnTermination: false,
              warningNotificationOnKill: Platform.isIOS,
              volumeSettings: VolumeSettings.fade(
                fadeDuration: const Duration(seconds: 10),
                volume: 1.0,
              ),
              notificationSettings: NotificationSettings(
                title: 'Birthday Today!',
                body: "It's ${birthday.name}'s birthday! Show them some love 💕",
                stopButton: 'Stop',
              ),
              payload: birthday.id,
            ),
          );
          debugPrint(
            '[Alarm] D-Day scheduled for ${birthday.name} at $fireAt → success=$success',
          );
        } catch (e) {
          debugPrint('[Alarm] Failed to schedule D-Day for ${birthday.name}: $e');
        }
      }
    }

    // ── Advance reminder alarm ────────────────────────────────────
    if (birthday.enableThreeDaysAlarm && birthday.advanceRingtonePath != null) {
      final t = _parseTime(birthday.advanceAlarmTimeStr);
      // Base the advance date off the same D-Day reference so both alarms
      // stay in sync (same year).
      final dDayDate = _nextOccurrence(
        month: birthday.month,
        day: birthday.day,
        hour: t.hour,
        minute: t.minute,
        now: dDayRef,
      );
      var advanceDate = dDayDate.subtract(Duration(days: birthday.customAlarmDays));

      // If the advance date is already in the past (e.g. advance alarm just
      // fired, or customAlarmDays == 0 and D-Day is today), roll it to the
      // advance date for next year's D-Day.
      if (!advanceDate.isAfter(now)) {
        final nextYearDDay = _nextOccurrence(
          month: birthday.month,
          day: birthday.day,
          hour: t.hour,
          minute: t.minute,
          now: dDayDate.add(const Duration(seconds: 1)),
        );
        advanceDate = nextYearDDay.subtract(Duration(days: birthday.customAlarmDays));
      }

      final audioPath = _validatePath(birthday.advanceRingtonePath!);
      if (audioPath != null) {
        final daysLabel = birthday.customAlarmDays == 0
            ? 'today'
            : 'in ${birthday.customAlarmDays} day${birthday.customAlarmDays > 1 ? 's' : ''}';

        try {
          final success = await Alarm.set(
            alarmSettings: AlarmSettings(
              id: _advanceId(birthday.id),
              dateTime: advanceDate,
              assetAudioPath: audioPath,
              loopAudio: true,
              vibrate: true,
              // androidFullScreenIntent: true required for reliable notification
              // + audio on all Android versions. The Dart layer handles whether
              // to show the ring screen immediately or defer until unlock.
              androidFullScreenIntent: true,
              androidStopAlarmOnTermination: false,
              warningNotificationOnKill: Platform.isIOS,
              volumeSettings: VolumeSettings.fade(
                fadeDuration: const Duration(seconds: 10),
                volume: 1.0,
              ),
              notificationSettings: NotificationSettings(
                title: '🎁 Birthday Reminder!',
                body: "${birthday.name}'s birthday is $daysLabel! Time to prepare 🎁",
                stopButton: 'Stop',
              ),
              payload: birthday.id,
            ),
          );
          debugPrint(
            '[Alarm] Advance scheduled for ${birthday.name} at $advanceDate → success=$success',
          );
        } catch (e) {
          debugPrint('[Alarm] Failed to schedule advance for ${birthday.name}: $e');
        }
      }
    }
  }

  // ── Cancel ────────────────────────────────────────────────────
  Future<void> cancelBirthdayAlarms(String birthdayId) async {
    await Alarm.stop(_dDayId(birthdayId));
    await Alarm.stop(_advanceId(birthdayId));
    debugPrint('[Alarm] Cancelled alarms for birthday ID: $birthdayId');
  }

  // ── Helpers ───────────────────────────────────────────────────

  /// Validates that the audio path is usable by the alarm package.
  /// Returns the path if valid, null otherwise.
  String? _validatePath(String path) {
    // Flutter asset (bundled in APK) — always valid
    if (path.startsWith('assets/')) return path;

    // Relative path → alarm package resolves from app documents dir
    if (!path.startsWith('/')) return path;

    // Absolute path → verify file exists
    if (File(path).existsSync()) return path;

    debugPrint('[Alarm] Audio file not found: $path');
    return null;
  }

  ({int hour, int minute}) _parseTime(String timeStr) {
    try {
      final parts = timeStr.split(':');
      if (parts.length == 2) {
        return (hour: int.parse(parts[0]), minute: int.parse(parts[1]));
      }
    } catch (_) {}
    return (hour: 9, minute: 0);
  }

  DateTime _nextOccurrence({
    required int month,
    required int day,
    required int hour,
    required int minute,
    required DateTime now,
  }) {
    final year = now.year;
    final daysInMonth = DateTime(year, month + 1, 0).day;
    final effectiveDay = day.clamp(1, daysInMonth);

    var candidate = DateTime(year, month, effectiveDay, hour, minute);
    if (!candidate.isAfter(now)) {
      final daysInMonthNext = DateTime(year + 1, month + 1, 0).day;
      final effectiveDayNext = day.clamp(1, daysInMonthNext);
      candidate = DateTime(year + 1, month, effectiveDayNext, hour, minute);
    }
    return candidate;
  }
}
