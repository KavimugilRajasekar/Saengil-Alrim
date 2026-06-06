import 'dart:async';
import 'dart:convert';

import 'package:alarm/alarm.dart';
import 'package:alarm/utils/alarm_set.dart';
import 'package:awesome_notifications/awesome_notifications.dart';
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
  StreamSubscription<ReceivedAction>? _awesomeActionSubscription;

  // ── Deduplication ─────────────────────────────────────────────
  // Alarm ID is in this set from the moment we decide what to do with it
  // (show immediately OR defer) until the ring screen is dismissed.
  // This prevents any race between the stream replay, the 1-second check,
  // and the resumed flush from processing the same alarm twice.
  final Set<int> _handledAlarmIds = {};

  // ── Deferred queue ────────────────────────────────────────────
  // Alarms that fired while the device was locked. Stored here until
  // AppLifecycleState.resumed fires (user unlocks / brings app forward).
  final List<AlarmSettings> _pendingLockedAlarms = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // BehaviorSubject — replays the latest value immediately on subscribe,
    // so any alarm already ringing at launch is handled right away.
    _ringingSubscription = Alarm.ringing.listen(_onRingingChanged);

    // Listen to awesome notification click events while app is running
    _awesomeActionSubscription =
        NotificationController.actionStream.listen(_handleAwesomeAction);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Belt-and-suspenders: process current ringing state once the widget
      // tree is ready. The subscription above already covers this, but the
      // post-frame ensures the navigator is mounted before we try to push.
      await _processRingingSet(Alarm.ringing.value);

      // Race guard: AlarmService sometimes populates ringing IDs ~1 s after
      // Alarm.init() completes (e.g. on cold launch from a killed state).
      Future.delayed(const Duration(seconds: 1), () {
        if (mounted) _processRingingSet(Alarm.ringing.value);
      });

      // Handle notification-tap launch (unlocked device, app was killed).
      await _handleNotificationLaunchPayload();
      await _handleInitialAwesomeAction();
    });
  }

  // ── App lifecycle ──────────────────────────────────────────────
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _onResumed();
    }
  }

  /// Called when the app comes to the foreground.
  /// Flushes deferred locked alarms, then handles any notification tap.
  Future<void> _onResumed() async {
    // Flush alarms that were deferred because the device was locked.
    if (_pendingLockedAlarms.isNotEmpty) {
      // Snapshot and clear before iterating to avoid modification-during-iteration.
      final toShow = List<AlarmSettings>.from(_pendingLockedAlarms);
      _pendingLockedAlarms.clear();

      for (final alarm in toShow) {
        // Remove from handled set so _showAlarmScreen can proceed.
        // (_handleAlarm added the ID when deferring, which would otherwise
        //  block _showAlarmScreen's guard check.)
        _handledAlarmIds.remove(alarm.id);
        await _showAlarmScreen(alarm);
      }
    }

    // Also re-check the live stream — catches any alarm that started
    // ringing after the last stream event (edge case on some OEMs).
    await _processRingingSet(Alarm.ringing.value);

    // Check for a notification-tap payload (user tapped banner to open app).
    await _handleNotificationLaunchPayload();
  }

  // ── Stream handler ─────────────────────────────────────────────
  /// Called by the BehaviorSubject whenever the ringing set changes.
  void _onRingingChanged(AlarmSet alarmSet) {
    // Fire-and-forget: process serially via a sequential async chain is
    // overkill here because _handleAlarm's dedup guard (_handledAlarmIds)
    // is synchronously checked-and-set before any await, making it safe.
    _processRingingSet(alarmSet);
  }

  /// Processes every alarm in [alarmSet] once.
  Future<void> _processRingingSet(AlarmSet alarmSet) async {
    for (final alarm in alarmSet.alarms) {
      await _handleAlarm(alarm);
    }
  }

  // ── Device lock check ──────────────────────────────────────────
  Future<bool> _isDeviceLocked() async {
    try {
      final result = await _kChannel.invokeMethod<bool>('isDeviceLocked');
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  // ── Alarm routing ──────────────────────────────────────────────
  /// Single entry point for every alarm.
  /// Synchronously claims the alarm ID before any await, preventing races.
  Future<void> _handleAlarm(AlarmSettings alarm) async {
    // Synchronous claim — prevents any concurrent call from double-processing.
    if (_handledAlarmIds.contains(alarm.id)) return;
    _handledAlarmIds.add(alarm.id); // claimed

    final locked = await _isDeviceLocked();

    if (locked) {
      // Audio is already playing via the foreground service.
      // Defer the ring UI until the user unlocks.
      debugPrint('[Alarm] Locked — deferring UI for alarm ${alarm.id}');
      if (!_pendingLockedAlarms.any((a) => a.id == alarm.id)) {
        _pendingLockedAlarms.add(alarm);
      }
      // NOTE: We do NOT remove from _handledAlarmIds here.
      // If the stream replays before unlock, the claim prevents re-queueing.
      // _onResumed() removes the ID before calling _showAlarmScreen().
    } else {
      // Unlocked — show UI immediately.
      // Pass through to _showAlarmScreen which re-checks the guard
      // (it was added above, so it will proceed via the special path).
      await _showAlarmScreen(alarm, alreadyClaimed: true);
    }
  }

  /// Shows the AlarmRingScreen for [alarm].
  ///
  /// [alreadyClaimed] — true when called from _handleAlarm (ID already in
  /// _handledAlarmIds). False when called from _onResumed after removing
  /// the ID to flush a deferred alarm (guard re-checked inside).
  Future<void> _showAlarmScreen(
    AlarmSettings alarm, {
    bool alreadyClaimed = false,
  }) async {
    if (!alreadyClaimed) {
      if (_handledAlarmIds.contains(alarm.id)) return;
      _handledAlarmIds.add(alarm.id);
    }

    final birthday = await _loadBirthdayById(alarm.payload);

    final navigator = await _waitForNavigator();
    if (navigator == null) {
      // Navigator never became available — release the claim so it can retry.
      _handledAlarmIds.remove(alarm.id);
      return;
    }

    navigator.push(
      PageRouteBuilder(
        opaque: false,
        barrierDismissible: false,
        pageBuilder: (_, a, b) => AlarmRingScreen(
          alarmSettings: alarm,
          birthday: birthday,
          onDismissed: () => _handledAlarmIds.remove(alarm.id),
        ),
        transitionDuration: const Duration(milliseconds: 400),
        transitionsBuilder: (_, animation, __, child) => FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: Curves.easeIn),
          child: child,
        ),
      ),
    );
  }

  // ── Notification tap payload ───────────────────────────────────
  /// Handles cold-launch / resumed from a notification tap on an unlocked device.
  Future<void> _handleNotificationLaunchPayload() async {
    try {
      final payload =
          await _kChannel.invokeMethod<String?>('getNotificationLaunchPayload');
      if (payload == null || payload.isEmpty) return;

      debugPrint('[main] Notification tap payload: $payload');
      await _handleLaunchOrTapPayload(payload);
    } catch (e) {
      debugPrint('[main] _handleNotificationLaunchPayload error: $e');
    }
  }

  Future<void> _handleInitialAwesomeAction() async {
    final initialAction = NotificationController.initialAction ??
        await AwesomeNotifications().getInitialNotificationAction();
    if (initialAction != null) {
      final payload = initialAction.payload;
      if (payload != null && payload.containsKey('birthdayId')) {
        final birthdayId = payload['birthdayId'];
        if (birthdayId != null) {
          debugPrint('[main] Initial awesome notification action payload: $birthdayId');
          await _handleLaunchOrTapPayload(birthdayId);
        }
      }
    }
  }

  void _handleAwesomeAction(ReceivedAction action) async {
    final payload = action.payload;
    if (payload != null && payload.containsKey('birthdayId')) {
      final birthdayId = payload['birthdayId'];
      if (birthdayId != null) {
        debugPrint('[main] Awesome notification action payload: $birthdayId');
        await _handleLaunchOrTapPayload(birthdayId);
      }
    }
  }

  Future<void> _handleLaunchOrTapPayload(String payload) async {
    // If the alarm is still ringing, _processRingingSet handles the UI.
    final ringing = Alarm.ringing.value.alarms;
    final stillRinging = ringing.any((a) => a.payload == payload);
    if (stillRinging) return;

    // Alarm already stopped — build a synthetic settings object so the
    // ring screen can still show the birthday info and reschedule.
    final birthday = await _loadBirthdayById(payload);
    if (birthday == null) return;

    // Use a fixed sentinel ID for the synthetic alarm.
    // Only one synthetic screen can be on the stack at a time.
    const sentinelId = -1;
    if (_handledAlarmIds.contains(sentinelId)) return;
    _handledAlarmIds.add(sentinelId);

    final syntheticAlarm = AlarmSettings(
      id: sentinelId,
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
    if (navigator == null) {
      _handledAlarmIds.remove(sentinelId);
      return;
    }

    navigator.push(
      PageRouteBuilder(
        opaque: false,
        barrierDismissible: false,
        pageBuilder: (_, a, b) => AlarmRingScreen(
          alarmSettings: syntheticAlarm,
          birthday: birthday,
          onDismissed: () => _handledAlarmIds.remove(sentinelId),
        ),
        transitionDuration: const Duration(milliseconds: 400),
        transitionsBuilder: (_, animation, __, child) => FadeTransition(
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

  /// Polls for the navigator to become available (up to 6 s).
  Future<NavigatorState?> _waitForNavigator() async {
    for (int i = 0; i < 60; i++) {
      final state = navigatorKey.currentState;
      if (state != null) return state;
      await Future.delayed(const Duration(milliseconds: 100));
    }
    debugPrint('[main] Navigator not available after 6 s');
    return null;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ringingSubscription?.cancel();
    _awesomeActionSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [ChangeNotifierProvider(create: (_) => BirthdayProvider())],
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
