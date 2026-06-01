import 'package:alarm/alarm.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'birthday_service.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();
  final Alarm alarm = Alarm();

  Future<void> init() async {
    // 1. Initialize time zones
    tz.initializeTimeZones();
    try {
      final TimezoneInfo timeZoneInfo = await FlutterTimezone.getLocalTimezone();
      final String timeZoneName = timeZoneInfo.identifier;
      tz.setLocalLocation(tz.getLocation(timeZoneName));
    } catch (e) {
      debugPrint('Could not set local location: $e. Falling back to UTC.');
      tz.setLocalLocation(tz.getLocation('UTC'));
    }

    // 2. Initialize notification settings
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings initializationSettingsDarwin =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsDarwin,
    );

    await _notificationsPlugin.initialize(
      settings: initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse details) {
        debugPrint('Notification clicked: ${details.id}');
      },
    );

    // 3. Request permissions explicitly for Android 13+
    _requestAndroidPermissions();

    // 4. Initialize alarm package
    await Alarm.init();
  }

  Future<void> _requestAndroidPermissions() async {
    try {
      final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
          _notificationsPlugin.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      if (androidImplementation != null) {
        await androidImplementation.requestNotificationsPermission();
      }
    } catch (e) {
      debugPrint('Error requesting notifications permissions: $e');
    }
  }

  // Generate stable, unique notification IDs from a friend's string ID
  int _getNotificationId(String friendId, bool isThreeDaysBefore) {
    // String hashCode is stable during execution. We mask it to 30 bits to stay in safe 32-bit positive int range.
    final baseHash = friendId.hashCode & 0x3FFFFFFF;
    return isThreeDaysBefore ? baseHash + 1 : baseHash;
  }

  // Schedule D-day and advance customizable alarms
  Future<void> scheduleBirthdayAlarms(FriendBirthday birthday) async {
    // First cancel any existing alarms for this friend
    await cancelBirthdayAlarms(birthday.id);

    final now = DateTime.now();
    final currentYear = now.year;

    // Parse D-Day alarm time
    int dDayHour = 9;
    int dDayMinute = 0;
    try {
      final parts = birthday.dDayAlarmTimeStr.split(':');
      if (parts.length == 2) {
        dDayHour = int.parse(parts[0]);
        dDayMinute = int.parse(parts[1]);
      }
    } catch (e) {
      debugPrint('Error parsing D-Day alarm time: $e. Falling back to 9:00 AM');
    }

    // Parse advance alarm time
    int advanceHour = 9;
    int advanceMinute = 0;
    try {
      final parts = birthday.advanceAlarmTimeStr.split(':');
      if (parts.length == 2) {
        advanceHour = int.parse(parts[0]);
        advanceMinute = int.parse(parts[1]);
      }
    } catch (e) {
      debugPrint('Error parsing advance alarm time: $e. Falling back to 9:00 AM');
    }

    // Custom sound configuration for D-Day alarm
    final String? dDayRawSoundName = (birthday.dDayRingtonePath == 'chime' ||
            birthday.dDayRingtonePath == 'fairy' ||
            birthday.dDayRingtonePath == 'music_box')
        ? birthday.dDayRingtonePath
        : null;

    // Custom sound configuration for advance alarm
    final String? advanceRawSoundName = (birthday.advanceRingtonePath == 'chime' ||
            birthday.advanceRingtonePath == 'fairy' ||
            birthday.advanceRingtonePath == 'music_box')
        ? birthday.advanceRingtonePath
        : null;

    // D-Day Alarm scheduling
    if (birthday.enableDDayAlarm) {
      final dDayId = _getNotificationId(birthday.id, false);
      // Get the last day of the month for the current year to handle invalid dates (like Feb 29 in non-leap years)
      int daysInMonth = DateTime(currentYear, birthday.month + 1, 0).day;
      int effectiveDay = birthday.day > daysInMonth ? daysInMonth : birthday.day;
      var dDayDate = DateTime(currentYear, birthday.month, effectiveDay, dDayHour, dDayMinute);
      if (dDayDate.isBefore(now)) {
        dDayDate = DateTime(currentYear + 1, birthday.month, effectiveDay, dDayHour, dDayMinute);
      }

      // Custom sound configuration for D-Day alarm
      final AndroidNotificationDetails dDayAndroidDetails = AndroidNotificationDetails(
        dDayRawSoundName != null ? 'birthday_alarms_dDay_$dDayRawSoundName' : 'birthday_alarms_dDay',
        dDayRawSoundName != null ? 'Birthday Alarms D-Day ($dDayRawSoundName)' : 'Birthday Alarms D-Day',
        channelDescription: 'Reminders for your friends\' birthdays.',
        importance: Importance.high,
        priority: Priority.high,
        playSound: true,
        sound: dDayRawSoundName != null ? RawResourceAndroidNotificationSound(dDayRawSoundName) : null,
      );

      final DarwinNotificationDetails dDayIosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        sound: dDayRawSoundName != null ? '$dDayRawSoundName.mp3' : null,
      );

      final NotificationDetails dDayPlatformDetails = NotificationDetails(
        android: dDayAndroidDetails,
        iOS: dDayIosDetails,
      );

      try {
        final tzDDayDate = tz.TZDateTime.from(dDayDate, tz.local);
        await _notificationsPlugin.zonedSchedule(
          id: dDayId,
          title: 'Birthday Today! 🎂',
          body: 'It is ${birthday.name}\'s birthday today! Show them some love! 🎉',
          scheduledDate: tzDDayDate,
          notificationDetails: dDayPlatformDetails,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        );
        debugPrint('Scheduled D-Day alarm for ${birthday.name} at $dDayDate (ID: $dDayId, Sound: $dDayRawSoundName)');
      } catch (e) {
        debugPrint('Failed to schedule D-Day alarm: $e');
      }
    }

    // Advance customizable Alarm scheduling
    if (birthday.enableThreeDaysAlarm) {
      final advanceId = _getNotificationId(birthday.id, true);

      // Calculate D-Day first using the advance alarm time?
      // Actually, the advance reminder is based on the D-Day, but the time of day for the advance reminder is separate.
      // We calculate the D-Day date (month and day) and then use the advance alarm time for the time of day.
      // Get the last day of the month for the current year to handle invalid dates (like Feb 29 in non-leap years)
      int daysInMonth = DateTime(currentYear, birthday.month + 1, 0).day;
      int effectiveDay = birthday.day > daysInMonth ? daysInMonth : birthday.day;
      var dDayDateForAdvance = DateTime(currentYear, birthday.month, effectiveDay, advanceHour, advanceMinute);
      if (dDayDateForAdvance.isBefore(now)) {
        dDayDateForAdvance = DateTime(currentYear + 1, birthday.month, effectiveDay, advanceHour, advanceMinute);
      }
      var advanceDate = dDayDateForAdvance.subtract(Duration(days: birthday.customAlarmDays));

      // If advance date is already in the past, schedule it for the next occurrence next year
      if (advanceDate.isBefore(now)) {
        var nextDDayDate = DateTime(currentYear + 1, birthday.month, effectiveDay, advanceHour, advanceMinute);
        if (nextDDayDate.isBefore(now)) {
          nextDDayDate = DateTime(currentYear + 2, birthday.month, effectiveDay, advanceHour, advanceMinute);
        }
        advanceDate = nextDDayDate.subtract(Duration(days: birthday.customAlarmDays));
      }

      // Custom sound configuration for advance alarm
      final AndroidNotificationDetails advanceAndroidDetails = AndroidNotificationDetails(
        advanceRawSoundName != null ? 'birthday_alarms_advance_$advanceRawSoundName' : 'birthday_alarms_advance',
        advanceRawSoundName != null ? 'Birthday Alarms Advance ($advanceRawSoundName)' : 'Birthday Alarms Advance',
        channelDescription: 'Reminders for your friends\'birthdays.',
        importance: Importance.high,
        priority: Priority.high,
        playSound: true,
        sound: advanceRawSoundName != null ? RawResourceAndroidNotificationSound(advanceRawSoundName) : null,
      );

      final DarwinNotificationDetails advanceIosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        sound: advanceRawSoundName != null ? '$advanceRawSoundName.mp3' : null,
      );

      final NotificationDetails advancePlatformDetails = NotificationDetails(
        android: advanceAndroidDetails,
        iOS: advanceIosDetails,
      );

      try {
        final tzAdvanceDate = tz.TZDateTime.from(advanceDate, tz.local);
        final String bodyText = birthday.customAlarmDays == 0
            ? '${birthday.name}\'s birthday is today! Have you prepared a gift/card yet?'
            : '${birthday.name}\'s birthday is in ${birthday.customAlarmDays} days! Have you prepared a gift/card yet?';

        await _notificationsPlugin.zonedSchedule(
          id: advanceId,
          title: 'Birthday Upcoming! 🎁',
          body: bodyText,
          scheduledDate: tzAdvanceDate,
          notificationDetails: advancePlatformDetails,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        );
        debugPrint('Scheduled advance reminder (${birthday.customAlarmDays} days before) for ${birthday.name} at $advanceDate (ID: $advanceId, Sound: $advanceRawSoundName)');
      } catch (e) {
        debugPrint('Failed to schedule advance alarm: $e');
      }
    }
  }

  // Cancel alarms for a birthday entry
  Future<void> cancelBirthdayAlarms(String birthdayId) async {
    final dDayId = _getNotificationId(birthdayId, false);
    final threeDaysId = _getNotificationId(birthdayId, true);

    await _notificationsPlugin.cancel(id: dDayId);
    await _notificationsPlugin.cancel(id: threeDaysId);
    debugPrint('Cancelled alarms for ID $birthdayId (IDs: $dDayId, $threeDaysId)');
  }
}
