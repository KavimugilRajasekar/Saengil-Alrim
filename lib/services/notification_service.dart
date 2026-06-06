import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:alarm/alarm.dart';
import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

    // Initialize Awesome Notifications
    await AwesomeNotifications().initialize(
      null, // uses launcher icon by default
      [
        NotificationChannel(
          channelKey: 'birthday_channel',
          channelName: 'Birthday Alarms',
          channelDescription: 'Heads-up alarms and reminders for birthdays',
          defaultColor: const Color(0xFFFF6B9D),
          ledColor: const Color(0xFFFF6B9D),
          importance: NotificationImportance.Max,
          channelShowBadge: true,
          locked: true,
          defaultPrivacy: NotificationPrivacy.Public,
          playSound: false, // Handled by alarm package
          enableVibration: true,
        ),
      ],
      debug: kDebugMode,
    );

    // Register listeners
    await AwesomeNotifications().setListeners(
      onActionReceivedMethod: NotificationController.onActionReceivedMethod,
    );
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
          final dDayAlarmId = _dDayId(birthday.id);
          final success = await Alarm.set(
            alarmSettings: AlarmSettings(
              id: dDayAlarmId,
              dateTime: fireAt,
              assetAudioPath: audioPath,
              loopAudio: true,
              vibrate: true,
              // false → do NOT pop the ring screen over the lock screen.
              // The alarm service still plays audio as a foreground service.
              // Ring screen is shown only after the user unlocks the device.
              androidFullScreenIntent: false,
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
          if (success) {
            await AwesomeNotifications().createNotification(
              content: NotificationContent(
                id: dDayAlarmId,
                channelKey: 'birthday_channel',
                title: '🎂 Birthday Today!',
                body: "It's ${birthday.name}'s birthday! Show them some love 💕",
                wakeUpScreen: true,   // lights up screen for notification banner
                fullScreenIntent: false, // banner only — NOT a full-screen overlay
                criticalAlert: true,
                category: NotificationCategory.Alarm,
                payload: {
                  'birthdayId': birthday.id,
                  'alarmId': dDayAlarmId.toString(),
                },
              ),
              actionButtons: [
                NotificationActionButton(
                  key: 'STOP',
                  label: 'Stop',
                  actionType: ActionType.Default,
                ),
              ],
              schedule: NotificationCalendar(
                year: fireAt.year,
                month: fireAt.month,
                day: fireAt.day,
                hour: fireAt.hour,
                minute: fireAt.minute,
                second: 0,
                millisecond: 0,
                preciseAlarm: true,
                repeats: false,
              ),
            );
          }
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
          final advanceAlarmId = _advanceId(birthday.id);
          final success = await Alarm.set(
            alarmSettings: AlarmSettings(
              id: advanceAlarmId,
              dateTime: advanceDate,
              assetAudioPath: audioPath,
              loopAudio: true,
              vibrate: true,
              // false → do NOT pop the ring screen over the lock screen.
              // The alarm service still plays audio as a foreground service.
              // Ring screen is shown only after the user unlocks the device.
              androidFullScreenIntent: false,
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
          if (success) {
            await AwesomeNotifications().createNotification(
              content: NotificationContent(
                id: advanceAlarmId,
                channelKey: 'birthday_channel',
                title: '🎁 Birthday Reminder!',
                body: "${birthday.name}'s birthday is $daysLabel! Time to prepare 🎁",
                wakeUpScreen: true,   // lights up screen for notification banner
                fullScreenIntent: false, // banner only — NOT a full-screen overlay
                criticalAlert: true,
                category: NotificationCategory.Reminder,
                payload: {
                  'birthdayId': birthday.id,
                  'alarmId': advanceAlarmId.toString(),
                },
              ),
              actionButtons: [
                NotificationActionButton(
                  key: 'STOP',
                  label: 'Stop',
                  actionType: ActionType.Default,
                ),
              ],
              schedule: NotificationCalendar(
                year: advanceDate.year,
                month: advanceDate.month,
                day: advanceDate.day,
                hour: advanceDate.hour,
                minute: advanceDate.minute,
                second: 0,
                millisecond: 0,
                preciseAlarm: true,
                repeats: false,
              ),
            );
          }
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
    final dDayAlarmId = _dDayId(birthdayId);
    final advanceAlarmId = _advanceId(birthdayId);
    await Alarm.stop(dDayAlarmId);
    await Alarm.stop(advanceAlarmId);
    await AwesomeNotifications().cancel(dDayAlarmId);
    await AwesomeNotifications().cancel(advanceAlarmId);
    debugPrint('[Alarm/Awesome] Cancelled alarms and notifications for birthday ID: $birthdayId');
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

class NotificationController {
  static ReceivedAction? initialAction;
  static final StreamController<ReceivedAction> _actionStreamController =
      StreamController<ReceivedAction>.broadcast();
  static Stream<ReceivedAction> get actionStream => _actionStreamController.stream;

  /// Use @pragma("vm:entry-point") to keep the method reachable when the app is killed
  @pragma("vm:entry-point")
  static Future<void> onActionReceivedMethod(ReceivedAction receivedAction) async {
    // If the button is 'STOP', stop the alarm
    final payload = receivedAction.payload;
    if (payload != null) {
      final alarmIdStr = payload['alarmId'];
      if (alarmIdStr != null) {
        final alarmId = int.tryParse(alarmIdStr);
        if (alarmId != null) {
          if (receivedAction.buttonKeyPressed == 'STOP') {
            await Alarm.stop(alarmId);
            await AwesomeNotifications().cancel(alarmId);
            
            // Reschedule
            final birthdayId = payload['birthdayId'];
            if (birthdayId != null) {
              await _rescheduleAfterDismiss(birthdayId, alarmId);
            }
            return;
          }
        }
      }
    }

    if (receivedAction.actionLifeCycle == NotificationLifeCycle.Terminated) {
      initialAction = receivedAction;
    } else {
      _actionStreamController.add(receivedAction);
    }
  }

  static Future<void> _rescheduleAfterDismiss(String birthdayId, int firedId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString('saved_birthdays');
      if (json == null) return;

      final birthdays = (jsonDecode(json) as List<dynamic>)
          .map((e) => FriendBirthday.fromJson(e as Map<String, dynamic>))
          .toList();

      final birthday = birthdays.firstWhere((b) => b.id == birthdayId);
      // Reschedule next year's alarm
      await NotificationService().scheduleBirthdayAlarmsAfter(
        birthday,
        firedAlarmId: firedId,
      );
    } catch (e) {
      debugPrint('[NotificationController] Reschedule error: $e');
    }
  }
}
