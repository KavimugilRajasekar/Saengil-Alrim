import 'dart:async';
import 'dart:convert';

import 'package:alarm/alarm.dart';
import 'package:alarm/utils/alarm_set.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'screens/alarm_ring_screen.dart';
import 'screens/home_screen.dart';
import 'services/birthday_service.dart';
import 'services/notification_service.dart';
import 'widgets/app_styles.dart';

// ── Global navigator key so we can push from outside widget tree ──
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService().init();
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  StreamSubscription<AlarmSet>? _ringingSubscription;

  @override
  void initState() {
    super.initState();
    _listenToAlarms();
  }

  void _listenToAlarms() {
    // Alarm.ringing emits the current set of ringing alarms.
    // We listen for new additions and navigate to the ring screen.
    _ringingSubscription = Alarm.ringing.listen((alarmSet) {
      for (final alarmSettings in alarmSet.alarms) {
        _showAlarmScreen(alarmSettings);
      }
    });
  }

  Future<void> _showAlarmScreen(AlarmSettings alarmSettings) async {
    // Look up the birthday from SharedPreferences using the payload (birthday ID)
    FriendBirthday? birthday;
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString('saved_birthdays');
      if (json != null) {
        final List<dynamic> decoded = jsonDecode(json);
        final birthdays = decoded
            .map((item) => FriendBirthday.fromJson(item as Map<String, dynamic>))
            .toList();

        // payload holds the birthday ID
        final birthdayId = alarmSettings.payload;
        if (birthdayId != null) {
          birthday = birthdays.firstWhere(
            (b) => b.id == birthdayId,
            orElse: () => birthdays.first,
          );
        } else if (birthdays.isNotEmpty) {
          birthday = birthdays.first;
        }
      }
    } catch (e) {
      debugPrint('Error loading birthday for alarm screen: $e');
    }

    final context = navigatorKey.currentContext;
    if (context == null) return;

    // Avoid pushing duplicate screens
    final navigator = navigatorKey.currentState;
    if (navigator == null) return;

    navigator.push(
      PageRouteBuilder(
        opaque: false,
        barrierDismissible: false,
        pageBuilder: (context, animation, secondaryAnimation) => AlarmRingScreen(
          alarmSettings: alarmSettings,
          birthday: birthday,
        ),
        transitionDuration: const Duration(milliseconds: 400),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: CurvedAnimation(parent: animation, curve: Curves.easeIn),
            child: child,
          );
        },
      ),
    );
  }

  @override
  void dispose() {
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
