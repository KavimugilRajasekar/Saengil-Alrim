// cloud_service.dart
// Handles Firebase Realtime Database sync via REST API.
//
// DATA ISOLATION:
// Each device is assigned a permanent random userId (UUID v4) stored in
// SharedPreferences on first launch.  All cloud operations use the path:
//
//   /birthdays/<userId>/
//
// This prevents different users from reading or overwriting each other's data.
//
// SHARING:
// A user can share their userId (the "sync code") with a friend.
// The friend enters it in the Get sheet to pull that user's entries.

import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'birthday_service.dart';

const String _baseUrl =
    'https://minicoloud-default-rtdb.asia-southeast1.firebasedatabase.app/birthdays';

class CloudService {
  // ── User ID ───────────────────────────────────────────────────────────────

  /// Returns the persistent user ID for this device, creating one if needed.
  Future<String> getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    var id = prefs.getString('cloud_user_id');
    if (id == null || id.isEmpty) {
      id = _generateUuid();
      await prefs.setString('cloud_user_id', id);
    }
    return id;
  }

  /// Generates a simple UUID v4.
  String _generateUuid() {
    final rng = Random.secure();
    final bytes = List<int>.generate(16, (_) => rng.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40; // version 4
    bytes[8] = (bytes[8] & 0x3f) | 0x80; // variant
    String hex(int n) => n.toRadixString(16).padLeft(2, '0');
    return '${hex(bytes[0])}${hex(bytes[1])}${hex(bytes[2])}${hex(bytes[3])}'
        '-${hex(bytes[4])}${hex(bytes[5])}'
        '-${hex(bytes[6])}${hex(bytes[7])}'
        '-${hex(bytes[8])}${hex(bytes[9])}'
        '-${hex(bytes[10])}${hex(bytes[11])}${hex(bytes[12])}${hex(bytes[13])}${hex(bytes[14])}${hex(bytes[15])}';
  }

  // ── Push ──────────────────────────────────────────────────────────────────
  // Writes the local birthdays to THIS device's own cloud node.
  // Other users' nodes are never touched.
  Future<void> pushToCloud(List<FriendBirthday> localBirthdays) async {
    final userId = await getUserId();
    final Map<String, dynamic> payload = {
      for (final b in localBirthdays) b.id: _toCloudMap(b),
    };

    final response = await http.put(
      Uri.parse('$_baseUrl/$userId.json'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    );

    if (response.statusCode != 200) {
      throw Exception('Push failed: ${response.statusCode} ${response.body}');
    }
  }

  // ── Fetch own ─────────────────────────────────────────────────────────────
  // Returns all birthdays stored under THIS device's own cloud node.
  Future<List<FriendBirthday>> fetchOwnFromCloud() async {
    final userId = await getUserId();
    return _fetchForUser(userId);
  }

  // ── Fetch from a specific user ────────────────────────────────────────────
  // Used when the user enters a friend's sync code to import their birthdays.
  Future<List<FriendBirthday>> fetchFromUser(String targetUserId) async {
    final trimmed = targetUserId.trim();
    if (trimmed.isEmpty) throw Exception('Sync code cannot be empty.');
    return _fetchForUser(trimmed);
  }

  Future<List<FriendBirthday>> _fetchForUser(String userId) async {
    final response =
        await http.get(Uri.parse('$_baseUrl/$userId.json'));

    if (response.statusCode != 200) {
      throw Exception('Fetch failed: ${response.statusCode} ${response.body}');
    }

    final body = response.body;
    if (body == 'null' || body.isEmpty) return [];

    final Map<String, dynamic> raw =
        jsonDecode(body) as Map<String, dynamic>;
    return raw.values
        .map((v) => _fromCloudMap(v as Map<String, dynamic>))
        .toList();
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  /// Only the fields we sync to the cloud.
  Map<String, dynamic> _toCloudMap(FriendBirthday b) => {
        'id': b.id,
        'name': b.name,
        'month': b.month,
        'day': b.day,
        'birthYear': b.birthYear,
        'notes': b.notes,
      };

  /// Reconstruct a minimal FriendBirthday from cloud data.
  FriendBirthday _fromCloudMap(Map<String, dynamic> m) => FriendBirthday(
        id: m['id'] as String,
        name: m['name'] as String,
        month: m['month'] as int,
        day: m['day'] as int,
        birthYear: m['birthYear'] as int?,
        notes: m['notes'] as String? ?? '',
        sticker: randomSticker(),
        avatarColorIndex: 0,
      );
}
