import 'dart:async';
import 'dart:convert';

import 'package:alarm/alarm.dart';
import 'package:alarm/utils/alarm_set.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'screens/alarm_ring_screen.dart';
import 'screens/home_screen.dart';
import 'services/birthday_service.dart';
import 'services/notification_service.dart';
import 'widgets/app_styles.dart';

// ── Global navigator key ──────────────────────────────────────────
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// ── Method channel (shared with PermissionService) ───────────────
const _kChannel = MethodChannel('com.example.saengil_alrim/battery');

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Alarm.init() registers the Pigeon callback handler AND calls checkAlarm()
  // which detects alarms that fired while the app was killed/backgrounded.
  // Must complete before runApp so the ringing BehaviorSubject is seeded.
  await NotificationService().init(); // internally calls Alarm.init()

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  StreamSubscription<AlarmSet>? _ringingSubscription;

  // Deduplication: alarm ID is in this set while its ring screen is on the stack.
  final Set<int> _shownAlarmIds = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Subscribe to the ringing stream immediately.
    // Alarm.ringing is a BehaviorSubject — it replays the latest value to
    // every new subscriber, so we will receive any alarm that is already
    // ringing right now.
    _ringingSubscription = Alarm.ringing.listen(_onRingingChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Primary check: handle alarms already ringing (covers cold launch from
      // full-screen intent on locked screen).
      _onRingingChanged(Alarm.ringing.value);

      // Secondary check after 1 second: covers the race where AlarmService
      // populates ringingAlarmIds slightly after Alarm.init() completes.
      Future.delayed(const Duration(seconds: 1), () {
        if (mounted) _onRingingChanged(Alarm.ringing.value);
      });

      // Notification-tap check: when the device is UNLOCKED and the user taps
      // the alarm notification (app killed / bg / fg), MainActivity stores the
      // payload and we retrieve it here to navigate to AlarmRingScreen.
      // This is the fallback for when Alarm.ringing hasn't replayed yet.
      await _handleNotificationLaunchPayload();
    });
  }

  // ── App lifecycle ──────────────────────────────────────────────
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // App came to foreground (from background or lock screen).
      _onRingingChanged(Alarm.ringing.value);
      // Also check if a notification tap brought us here.
      _handleNotificationLaunchPayload();
    }
  }

  // ── Handle notification tap payload from native side ──────────
  // Called on cold launch and on every resume. MainActivity stores the
  // birthday ID from the notification tap intent; we consume it once.
  Future<void> _handleNotificationLaunchPayload() async {
    try {
      final payload = await _kChannel.invokeMethod<String?>(
        'getNotificationLaunchPayload',
      );
      if (payload == null || payload.isEmpty) return;

      debugPrint('[main] Notification tap payload: $payload');

      // If Alarm.ringing already has this alarm, _onRingingChanged will handle
      // it. But if the alarm was already stopped (e.g. user dismissed from
      // notification shade) we still want to show the ring screen.
      // Check if any ringing alarm matches this payload first.
      final ringing = Alarm.ringing.value.alarms;
      final matchingAlarm = ringing.cast<AlarmSettings?>().firstWhere(
        (a) => a?.payload == payload,
        orElse: () => null,
      );

      if (matchingAlarm != null) {
        // Already handled by _onRingingChanged — skip to avoid duplicate screen.
        return;
      }

      // No ringing alarm found for this payload — the alarm may have been
      // stopped already or the stream hasn't updated yet. Load the birthday
      // and show the ring screen using a synthetic AlarmSettings.
      final birthday = await _loadBirthdayById(payload);
      if (birthday == null) return;

      // Build a minimal AlarmSettings just to pass to AlarmRingScreen.
      // The screen only uses id, payload, and the birthday object.
      final syntheticSettings = AlarmSettings(
        id: 0,
        dateTime: DateTime.now(),
        assetAudioPath: '',
        volumeSettings: const VolumeSettings.fixed(volume: 1.0),
        notificationSettings: const NotificationSettings(
          title: 'Birthday Alarm',
          body: '',
        ),
        payload: payload,
      );

      final navigator = await _waitForNavigator();
      if (navigator == null) return;

      // Use a unique sentinel ID (-1) for dedup so it doesn't clash with real IDs.
      const sentinelId = -1;
      if (_shownAlarmIds.contains(sentinelId)) return;
      _shownAlarmIds.add(sentinelId);

      navigator.push(
        PageRouteBuilder(
          opaque: false,
          barrierDismissible: false,
          pageBuilder: (_, a, b) => AlarmRingScreen(
            alarmSettings: syntheticSettings,
            birthday: birthday,
            onDismissed: () => _shownAlarmIds.remove(sentinelId),
          ),
          transitionDuration: const Duration(milliseconds: 400),
          transitionsBuilder: (_, animation, a, child) => FadeTransition(
            opacity: CurvedAnimation(parent: animation, curve: Curves.easeIn),
            child: child,
          ),
        ),
      );
    } catch (e) {
      debugPrint('[main] _handleNotificationLaunchPayload error: $e');
    }
  }

  // ── Central ringing handler ────────────────────────────────────
  void _onRingingChanged(AlarmSet alarmSet) {
    for (final alarm in alarmSet.alarms) {
      _showAlarmScreen(alarm);
    }
  }

  Future<void> _showAlarmScreen(AlarmSettings alarmSettings) async {
    // Never push two screens for the same alarm.
    if (_shownAlarmIds.contains(alarmSettings.id)) return;
    _shownAlarmIds.add(alarmSettings.id);

    final birthday = await _loadBirthdayById(alarmSettings.payload);

    // Wait for the navigator (up to 3 s on cold launch from notification).
    final navigator = await _waitForNavigator();
    if (navigator == null) {
      _shownAlarmIds.remove(alarmSettings.id);
      return;
    }

    navigator.push(
      PageRouteBuilder(
        opaque: false,
        barrierDismissible: false,
        pageBuilder: (_, a, b) => AlarmRingScreen(
          alarmSettings: alarmSettings,
          birthday: birthday,
          onDismissed: () => _shownAlarmIds.remove(alarmSettings.id),
        ),
        transitionDuration: const Duration(milliseconds: 400),
        transitionsBuilder: (_, animation, a, child) => FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: Curves.easeIn),
          child: child,
        ),
      ),
    );
  }

  // ── Helpers ────────────────────────────────────────────────────

  Future<FriendBirthday?> _loadBirthdayById(String? birthdayId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString('saved_birthdays');
      if (json == null) return null;

      final birthdays = (jsonDecode(json) as List<dynamic>)
          .map((e) => FriendBirthday.fromJson(e as Map<String, dynamic>))
          .toList();

      if (birthdays.isEmpty) return null;
      if (birthdayId == null) return birthdays.first;

      return birthdays.firstWhere(
        (b) => b.id == birthdayId,
        orElse: () => birthdays.first,
      );
    } catch (e) {
      debugPrint('[AlarmScreen] Error loading birthday: $e');
      return null;
    }
  }

  /// Polls for the navigator up to 3 seconds (30 × 100 ms).
  Future<NavigatorState?> _waitForNavigator() async {
    for (int i = 0; i < 30; i++) {
      final state = navigatorKey.currentState;
      if (state != null) return state;
      await Future.delayed(const Duration(milliseconds: 100));
    }
    return null;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ringingSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => BirthdayProvider()),
      ],
      child: MaterialApp(
        title: '생일알림',
        navigatorKey: navigatorKey,
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          fontFamily: AppStyles.bubblyFont,
          scaffoldBackgroundColor: AppColors.creamBg,
          colorScheme: ColorScheme.fromSeed(
            seedColor: AppColors.primaryPink,
            primary: AppColors.primaryPink,
            secondary: AppColors.secondaryApricot,
            surface: AppColors.cardBg,
          ),
          appBarTheme: const AppBarTheme(
            backgroundColor: Colors.transparent,
            elevation: 0,
            iconTheme: IconThemeData(color: AppColors.textDark),
          ),
        ),
        home: const HomeScreen(),
      ),
    );
  }
}
