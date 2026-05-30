import 'birthday_task.dart';

class FriendBirthday {
  final String id;
  final String name;
  final int month;
  final int day;
  final int? birthYear;
  final String sticker;
  final String notes;
  final List<BirthdayTask> tasks;
  final int avatarColorIndex;
  final bool enableDDayAlarm;
  final bool enableThreeDaysAlarm; // Serves as the advance reminder toggle
  // For advance reminder
  final int customAlarmDays; // Days before to trigger (default: 3)
  final String advanceAlarmTimeStr; // "HH:MM" 24h format (default: "09:00")
  final String? advanceRingtonePath; // Local path or bundle name
  final String? advanceRingtoneName; // Friendly display label
  // For D-Day alarm
  final String dDayAlarmTimeStr; // "HH:MM" 24h format (default: "09:00")
  final String? dDayRingtonePath; // Local path or bundle name
  final String? dDayRingtoneName; // Friendly display label

  FriendBirthday({
    required this.id,
    required this.name,
    required this.month,
    required this.day,
    this.birthYear,
    required this.sticker,
    this.notes = '',
    required this.tasks,
    required this.avatarColorIndex,
    this.enableDDayAlarm = true,
    this.enableThreeDaysAlarm = true,
    this.customAlarmDays = 3,
    this.advanceAlarmTimeStr = '09:00',
    this.advanceRingtonePath,
    this.advanceRingtoneName,
    this.dDayAlarmTimeStr = '09:00',
    this.dDayRingtonePath,
    this.dDayRingtoneName,
  });

  // Calculate days remaining until next birthday
  int get daysUntil {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // Get the last day of the month for the current year to handle invalid dates (like Feb 29 in non-leap years)
    int daysInMonth = DateTime(now.year, month + 1, 0).day;
    int effectiveDay = day > daysInMonth ? daysInMonth : day;

    var targetDate = DateTime(now.year, month, effectiveDay);

    if (targetDate.isBefore(today)) {
      targetDate = DateTime(now.year + 1, month, effectiveDay);
    }

    return targetDate.difference(today).inDays;
  }

  // Check if birthday is today
  bool get isToday {
    final now = DateTime.now();
    return now.month == month && now.day == day;
  }

  // Calculate the age the person is turning (if birthYear is specified)
  int? get ageTurning {
    if (birthYear == null) return null;
    final now = DateTime.now();

    // Get the last day of the month for the current year to handle invalid dates (like Feb 29 in non-leap years)
    int daysInMonth = DateTime(now.year, month + 1, 0).day;
    int effectiveDay = day > daysInMonth ? daysInMonth : day;

    var targetYear = now.year;
    var targetDate = DateTime(now.year, month, effectiveDay);
    final today = DateTime(now.year, now.month, now.day);

    if (targetDate.isBefore(today)) {
      targetYear = now.year + 1;
    }

    return targetYear - birthYear!;
  }

  double get taskProgress {
    if (tasks.isEmpty) return 0.0;
    final completed = tasks.where((t) => t.isCompleted).length;
    return completed / tasks.length;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'month': month,
      'day': day,
      'birthYear': birthYear,
      'sticker': sticker,
      'notes': notes,
      'tasks': tasks.map((t) => t.toJson()).toList(),
      'avatarColorIndex': avatarColorIndex,
      'enableDDayAlarm': enableDDayAlarm,
      'enableThreeDaysAlarm': enableThreeDaysAlarm,
      'customAlarmDays': customAlarmDays,
      'advanceAlarmTimeStr': advanceAlarmTimeStr,
      'advanceRingtonePath': advanceRingtonePath,
      'advanceRingtoneName': advanceRingtoneName,
      'dDayAlarmTimeStr': dDayAlarmTimeStr,
      'dDayRingtonePath': dDayRingtonePath,
      'dDayRingtoneName': dDayRingtoneName,
    };
  }

  factory FriendBirthday.fromJson(Map<String, dynamic> json) {
    var rawTasks = json['tasks'] as List? ?? [];
    return FriendBirthday(
      id: json['id'] as String,
      name: json['name'] as String,
      month: json['month'] as int,
      day: json['day'] as int,
      birthYear: json['birthYear'] as int?,
      sticker: json['sticker'] as String? ?? '🎂',
      notes: json['notes'] as String? ?? '',
      tasks: rawTasks.map((t) => BirthdayTask.fromJson(t as Map<String, dynamic>)).toList(),
      avatarColorIndex: json['avatarColorIndex'] as int? ?? 0,
      enableDDayAlarm: json['enableDDayAlarm'] as bool? ?? true,
      enableThreeDaysAlarm: json['enableThreeDaysAlarm'] as bool? ?? true,
      customAlarmDays: json['customAlarmDays'] as int? ?? 3,
      advanceAlarmTimeStr: json['advanceAlarmTimeStr'] as String? ?? '09:00',
      advanceRingtonePath: json['advanceRingtonePath'] as String?,
      advanceRingtoneName: json['advanceRingtoneName'] as String?,
      dDayAlarmTimeStr: json['dDayAlarmTimeStr'] as String? ?? '09:00',
      dDayRingtonePath: json['dDayRingtonePath'] as String?,
      dDayRingtoneName: json['dDayRingtoneName'] as String?,
    );
  }

  FriendBirthday copyWith({
    String? id,
    String? name,
    int? month,
    int? day,
    int? birthYear,
    String? sticker,
    String? notes,
    List<BirthdayTask>? tasks,
    int? avatarColorIndex,
    bool? enableDDayAlarm,
    bool? enableThreeDaysAlarm,
    int? customAlarmDays,
    String? advanceAlarmTimeStr,
    String? advanceRingtonePath,
    String? advanceRingtoneName,
    String? dDayAlarmTimeStr,
    String? dDayRingtonePath,
    String? dDayRingtoneName,
  }) {
    return FriendBirthday(
      id: id ?? this.id,
      name: name ?? this.name,
      month: month ?? this.month,
      day: day ?? this.day,
      birthYear: birthYear ?? this.birthYear,
      sticker: sticker ?? this.sticker,
      notes: notes ?? this.notes,
      tasks: tasks ?? this.tasks,
      avatarColorIndex: avatarColorIndex ?? this.avatarColorIndex,
      enableDDayAlarm: enableDDayAlarm ?? this.enableDDayAlarm,
      enableThreeDaysAlarm: enableThreeDaysAlarm ?? this.enableThreeDaysAlarm,
      customAlarmDays: customAlarmDays ?? this.customAlarmDays,
      advanceAlarmTimeStr: advanceAlarmTimeStr ?? this.advanceAlarmTimeStr,
      advanceRingtonePath: advanceRingtonePath ?? this.advanceRingtonePath,
      advanceRingtoneName: advanceRingtoneName ?? this.advanceRingtoneName,
      dDayAlarmTimeStr: dDayAlarmTimeStr ?? this.dDayAlarmTimeStr,
      dDayRingtonePath: dDayRingtonePath ?? this.dDayRingtonePath,
      dDayRingtoneName: dDayRingtoneName ?? this.dDayRingtoneName,
    );
  }
}
