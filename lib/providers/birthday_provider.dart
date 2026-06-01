import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/friend_birthday.dart';
import '../services/notification_service.dart';

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

  // Set and notify selected date for calendar
  void setSelectedDate(DateTime date) {
    _selectedDate = date;
    notifyListeners();
  }

  // Filter birthdays matching the selected date (month and day only)
  List<FriendBirthday> get birthdaysForSelectedDate {
    return _birthdays.where((birthday) {
      return birthday.month == _selectedDate.month && birthday.day == _selectedDate.day;
    }).toList();
  }

  // Sort upcoming birthdays: those with fewest days remaining first
  List<FriendBirthday> get upcomingBirthdays {
    final sorted = List<FriendBirthday>.from(_birthdays);
    sorted.sort((a, b) => a.daysUntil.compareTo(b.daysUntil));
    return sorted;
  }

  // Load birthdays from SharedPreferences
  Future<void> loadBirthdays() async {
    _isLoading = true;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      final String? birthdaysJson = prefs.getString('saved_birthdays');

      if (birthdaysJson != null) {
        final List<dynamic> decoded = jsonDecode(birthdaysJson);
        _birthdays = decoded.map((item) => FriendBirthday.fromJson(item as Map<String, dynamic>)).toList();
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

  // Save birthdays to SharedPreferences
  Future<void> saveBirthdaysToPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String encoded = jsonEncode(_birthdays.map((b) => b.toJson()).toList());
      await prefs.setString('saved_birthdays', encoded);
    } catch (e) {
      debugPrint('Error saving birthdays: $e');
    }
  }

  // Add a new birthday
  Future<void> addBirthday(FriendBirthday birthday) async {
    _birthdays.add(birthday);
    notifyListeners();
    await saveBirthdaysToPrefs();
    await NotificationService().scheduleBirthdayAlarms(birthday);
  }

  // Update an existing birthday details
  Future<void> updateBirthday(FriendBirthday updated) async {
    final index = _birthdays.indexWhere((b) => b.id == updated.id);
    if (index != -1) {
      _birthdays[index] = updated;
      notifyListeners();
      await saveBirthdaysToPrefs();
      await NotificationService().scheduleBirthdayAlarms(updated);
    }
  }

  // Delete a birthday
  Future<void> deleteBirthday(String id) async {
    _birthdays.removeWhere((b) => b.id == id);
    notifyListeners();
    await saveBirthdaysToPrefs();
    await NotificationService().cancelBirthdayAlarms(id);
  }

  // Reschedule all alarms to keep them synced with actual local time
  Future<void> _rescheduleAllAlarms() async {
    for (final b in _birthdays) {
      await NotificationService().scheduleBirthdayAlarms(b);
    }
  }

}