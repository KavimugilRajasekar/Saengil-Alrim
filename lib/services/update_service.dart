import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

/// Compares two semver strings (e.g. "1.2.3" vs "1.0.0").
/// Returns true if [remote] is strictly newer than [local].
bool _isNewer(String local, String remote) {
  List<int> parse(String v) =>
      v.replaceAll(RegExp(r'[^0-9.]'), '').split('.').map((p) {
        final n = int.tryParse(p);
        return n ?? 0;
      }).toList();

  final l = parse(local);
  final r = parse(remote);
  final len = r.length > l.length ? r.length : l.length;
  for (var i = 0; i < len; i++) {
    final lv = i < l.length ? l[i] : 0;
    final rv = i < r.length ? r[i] : 0;
    if (rv > lv) return true;
    if (rv < lv) return false;
  }
  return false;
}

class UpdateService {
  static const _apiUrl =
      'https://api.github.com/repos/kavimugilrajasekar/Saengil-Alrim/releases/latest';

  /// Checks GitHub for a newer release.
  /// Returns a [UpdateInfo] if a newer version exists, otherwise null.
  /// Returns null silently on any network/parse error.
  Future<UpdateInfo?> checkForUpdate() async {
    if (!Platform.isAndroid) return null;

    try {
      final response = await http
          .get(Uri.parse(_apiUrl), headers: {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) return null;

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final tagName = (data['tag_name'] as String? ?? '').replaceAll('v', '');
      final body = data['body'] as String? ?? '';
      final htmlUrl = data['html_url'] as String? ?? '';

      // Try to find a direct APK asset download URL
      String? apkUrl;
      final assets = data['assets'] as List<dynamic>? ?? [];
      for (final asset in assets) {
        final name = (asset['name'] as String? ?? '').toLowerCase();
        if (name.endsWith('.apk')) {
          apkUrl = asset['browser_download_url'] as String?;
          break;
        }
      }

      if (tagName.isEmpty) return null;

      final info = await PackageInfo.fromPlatform();
      final currentVersion = info.version;

      if (_isNewer(currentVersion, tagName)) {
        return UpdateInfo(
          currentVersion: currentVersion,
          latestVersion: tagName,
          releaseNotes: body,
          downloadUrl: apkUrl ?? htmlUrl,
        );
      }
    } catch (_) {
      // Silently ignore — offline app, network is optional
    }
    return null;
  }
}

class UpdateInfo {
  final String currentVersion;
  final String latestVersion;
  final String releaseNotes;
  final String downloadUrl;

  const UpdateInfo({
    required this.currentVersion,
    required this.latestVersion,
    required this.releaseNotes,
    required this.downloadUrl,
  });
}

/// Shows the update dialog. User can tap "Download" (opens browser) or dismiss.
Future<void> showUpdateDialog(BuildContext context, UpdateInfo info) async {
  return showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) => _UpdateDialog(info: info),
  );
}

class _UpdateDialog extends StatelessWidget {
  final UpdateInfo info;
  const _UpdateDialog({required this.info});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: const Color(0xFFFFF8F0),
      title: Row(
        children: const [
          Text('🎉', style: TextStyle(fontSize: 22)),
          SizedBox(width: 8),
          Text(
            'Update Available',
            style: TextStyle(
              fontFamily: 'Comfortaa',
              fontWeight: FontWeight.w700,
              fontSize: 18,
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'v${info.currentVersion}  →  v${info.latestVersion}',
            style: const TextStyle(
              fontFamily: 'Comfortaa',
              fontSize: 13,
              color: Color(0xFF888888),
            ),
          ),
          if (info.releaseNotes.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Text(
              "What's new:",
              style: TextStyle(
                fontFamily: 'Comfortaa',
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 4),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 120),
              child: SingleChildScrollView(
                child: Text(
                  info.releaseNotes,
                  style: const TextStyle(
                    fontFamily: 'Comfortaa',
                    fontSize: 12,
                    color: Color(0xFF555555),
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 10),
          const Text(
            'The download will open in your browser.',
            style: TextStyle(
              fontFamily: 'Comfortaa',
              fontSize: 11,
              color: Color(0xFFAAAAAA),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text(
            'Later',
            style: TextStyle(
              fontFamily: 'Comfortaa',
              color: Color(0xFF999999),
            ),
          ),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFFFB347),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          onPressed: () async {
            Navigator.of(context).pop();
            final uri = Uri.tryParse(info.downloadUrl);
            if (uri != null && await canLaunchUrl(uri)) {
              await launchUrl(uri, mode: LaunchMode.externalApplication);
            }
          },
          child: const Text(
            'Download',
            style: TextStyle(fontFamily: 'Comfortaa', fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}
