// birthday_service.dart
// Combines: models/friend_birthday.dart + providers/birthday_provider.dart
// All birthday data logic, persistence, and state management in one place.

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'notification_service.dart';

// ─────────────────────────────────────────────
// MODEL
// ─────────────────────────────────────────────

class FriendBirthday {
  final String id;
  final String name;
  final int month;
  final int day;
  final int? birthYear;
  final String sticker;
  final String notes;
  final int avatarColorIndex;
  final bool enableDDayAlarm;
  final bool enableThreeDaysAlarm; // generic advance reminder toggle
  final int customAlarmDays;
  final String advanceAlarmTimeStr; // "HH:MM" 24h
  final String? advanceRingtonePath;
  final String? advanceRingtoneName;
  final String dDayAlarmTimeStr; // "HH:MM" 24h
  final String? dDayRingtonePath;
  final String? dDayRingtoneName;

  const FriendBirthday({
    required this.id,
    required this.name,
    required this.month,
    required this.day,
    this.birthYear,
    required this.sticker,
    this.notes = '',
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

  // Days until next birthday (handles Feb 29 in non-leap years)
  int get daysUntil {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final daysInMonth = DateTime(now.year, month + 1, 0).day;
    final effectiveDay = day > daysInMonth ? daysInMonth : day;
    var target = DateTime(now.year, month, effectiveDay);
    if (target.isBefore(today)) {
      target = DateTime(now.year + 1, month, effectiveDay);
    }
    return target.difference(today).inDays;
  }

  bool get isToday {
    final now = DateTime.now();
    return now.month == month && now.day == day;
  }

  int? get ageTurning {
    if (birthYear == null) return null;
    final now = DateTime.now();
    final daysInMonth = DateTime(now.year, month + 1, 0).day;
    final effectiveDay = day > daysInMonth ? daysInMonth : day;
    var targetYear = now.year;
    final target = DateTime(now.year, month, effectiveDay);
    final today = DateTime(now.year, now.month, now.day);
    if (target.isBefore(today)) targetYear = now.year + 1;
    return targetYear - birthYear!;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'month': month,
        'day': day,
        'birthYear': birthYear,
        'sticker': sticker,
        'notes': notes,
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

  factory FriendBirthday.fromJson(Map<String, dynamic> json) => FriendBirthday(
        id: json['id'] as String,
        name: json['name'] as String,
        month: json['month'] as int,
        day: json['day'] as int,
        birthYear: json['birthYear'] as int?,
        sticker: json['sticker'] as String? ?? '🎂',
        notes: json['notes'] as String? ?? '',
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

  FriendBirthday copyWith({
    String? id,
    String? name,
    int? month,
    int? day,
    int? birthYear,
    String? sticker,
    String? notes,
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
  }) =>
      FriendBirthday(
        id: id ?? this.id,
        name: name ?? this.name,
        month: month ?? this.month,
        day: day ?? this.day,
        birthYear: birthYear ?? this.birthYear,
        sticker: sticker ?? this.sticker,
        notes: notes ?? this.notes,
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

// ─────────────────────────────────────────────
// PROVIDER
// ─────────────────────────────────────────────

class BirthdayProvider with ChangeNotifier {
  List<FriendBirthday> _birthdays = [];
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = true;

  List<FriendBirthday> get birthdays => _birthdays;
  DateTime get selectedDate => _selectedDate;
  bool get isLoading => _isLoading;

  BirthdayProvider() {
    loadBirthdays();
  }

  void setSelectedDate(DateTime date) {
    _selectedDate = date;
    notifyListeners();
  }

  List<FriendBirthday> get birthdaysForSelectedDate => _birthdays
      .where((b) => b.month == _selectedDate.month && b.day == _selectedDate.day)
      .toList();

  List<FriendBirthday> get upcomingBirthdays {
    final sorted = List<FriendBirthday>.from(_birthdays);
    sorted.sort((a, b) => a.daysUntil.compareTo(b.daysUntil));
    return sorted;
  }

  Future<void> loadBirthdays() async {
    _isLoading = true;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? json = prefs.getString('saved_birthdays');
      if (json != null) {
        final List<dynamic> decoded = jsonDecode(json);
        _birthdays = decoded
            .map((item) => FriendBirthday.fromJson(item as Map<String, dynamic>))
            .toList();
      } else {
        _birthdays = [];
      }
      await _rescheduleAllAlarms();
    } catch (e) {
      debugPrint('Error loading birthdays: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _saveToDisk() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'saved_birthdays',
        jsonEncode(_birthdays.map((b) => b.toJson()).toList()),
      );
    } catch (e) {
      debugPrint('Error saving birthdays: $e');
    }
  }

  Future<void> addBirthday(FriendBirthday birthday) async {
    _birthdays.add(birthday);
    notifyListeners();
    await _saveToDisk();
    await NotificationService().scheduleBirthdayAlarms(birthday);
  }

  Future<void> updateBirthday(FriendBirthday updated) async {
    final index = _birthdays.indexWhere((b) => b.id == updated.id);
    if (index != -1) {
      _birthdays[index] = updated;
      notifyListeners();
      await _saveToDisk();
      await NotificationService().scheduleBirthdayAlarms(updated);
    }
  }

  Future<void> deleteBirthday(String id) async {
    _birthdays.removeWhere((b) => b.id == id);
    notifyListeners();
    await _saveToDisk();
    await NotificationService().cancelBirthdayAlarms(id);
  }

  Future<void> _rescheduleAllAlarms() async {
    for (final b in _birthdays) {
      await NotificationService().scheduleBirthdayAlarms(b);
    }
  }
}
