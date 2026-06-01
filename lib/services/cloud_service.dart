// cloud_service.dart
// Handles Firebase Realtime Database sync via REST API.
// Stores only: name, DOB (month/day/birthYear), notes.

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'birthday_service.dart';

const String _baseUrl =
    'https://minicoloud-default-rtdb.asia-southeast1.firebasedatabase.app/birthdays';

class CloudService {
  // ── Push ──────────────────────────────────────────────────────────────────
  // Reads existing cloud data, merges with local (local wins on conflict by id),
  // then writes the full merged set back to Firebase.
  Future<void> pushToCloud(List<FriendBirthday> localBirthdays) async {
    // 1. Fetch current cloud data
    final existing = await fetchFromCloud();
    final Map<String, Map<String, dynamic>> merged = {
      for (final b in existing) b.id: _toCloudMap(b),
    };

    // 2. Overwrite / add local entries (local wins)
    for (final b in localBirthdays) {
      merged[b.id] = _toCloudMap(b);
    }

    // 3. Write back
    final response = await http.put(
      Uri.parse('$_baseUrl.json'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(merged),
    );

    if (response.statusCode != 200) {
      throw Exception('Push failed: ${response.statusCode} ${response.body}');
    }
  }

  // ── Fetch ─────────────────────────────────────────────────────────────────
  // Returns all birthdays stored in the cloud.
  Future<List<FriendBirthday>> fetchFromCloud() async {
    final response = await http.get(Uri.parse('$_baseUrl.json'));

    if (response.statusCode != 200) {
      throw Exception('Fetch failed: ${response.statusCode} ${response.body}');
    }

    final body = response.body;
    if (body == 'null' || body.isEmpty) return [];

    final Map<String, dynamic> raw = jsonDecode(body) as Map<String, dynamic>;
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
  /// Fields not stored in the cloud get sensible defaults.
  FriendBirthday _fromCloudMap(Map<String, dynamic> m) => FriendBirthday(
        id: m['id'] as String,
        name: m['name'] as String,
        month: m['month'] as int,
        day: m['day'] as int,
        birthYear: m['birthYear'] as int?,
        notes: m['notes'] as String? ?? '',
        sticker: '🎂',
        avatarColorIndex: 0,
      );
}
