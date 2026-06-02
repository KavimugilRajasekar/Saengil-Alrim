import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/birthday_service.dart';
import '../services/permission_service.dart';
import '../services/update_service.dart';
import '../widgets/app_styles.dart';
import '../widgets/birthday_card.dart';
import '../widgets/funky_calendar.dart';
import 'add_birthday_screen.dart';
import 'saved_birthdays_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  List<MissingPermission> _missingPermissions = [];
  bool _permissionsChecked = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Check after first frame so the UI is ready
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkPermissions();
      _checkForUpdate();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Re-check when user returns from Settings
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _permissionsChecked) {
      _checkPermissions();
    }
  }

  Future<void> _checkPermissions() async {
    if (!Platform.isAndroid) return;
    final missing = await PermissionService().checkAll();
    if (mounted) {
      setState(() {
        _missingPermissions = missing;
        _permissionsChecked = true;
      });
    }
  }

  Future<void> _checkForUpdate() async {
    final info = await UpdateService().checkForUpdate();
    if (info != null && mounted) {
      // Small delay so the UI is fully settled before showing the dialog
      await Future.delayed(const Duration(milliseconds: 800));
      if (mounted) {
        await showUpdateDialog(context, info);
      }
    }
  }

  void _showSavedBirthdaysSheet(BuildContext context) {
    final sheetController = DraggableScrollableController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      enableDrag: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        controller: sheetController,
        initialChildSize: 0.4,
        minChildSize: 0.0,
        maxChildSize: 1.0,
        snap: true,
        snapSizes: const [0.0, 1.0],
        expand: false,
        builder: (context, scrollController) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            sheetController.animateTo(
              1.0,
              duration: const Duration(milliseconds: 380),
              curve: Curves.easeOutCubic,
            );
          });
          return SavedBirthdaysSheet(scrollController: scrollController);
        },
      ),
    );
  }

  void _showAddBirthdaySheet(BuildContext context) {
    final provider = Provider.of<BirthdayProvider>(context, listen: false);
    final sheetController = DraggableScrollableController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      enableDrag: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        controller: sheetController,
        initialChildSize: 0.4,
        minChildSize: 0.0,
        maxChildSize: 1.0,
        snap: true,
        snapSizes: const [0.0, 1.0],
        expand: false,
        builder: (context, scrollController) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            sheetController.animateTo(
              1.0,
              duration: const Duration(milliseconds: 380),
              curve: Curves.easeOutCubic,
            );
          });
          return AddBirthdayScreen(
            initialDate: provider.selectedDate,
            scrollController: scrollController,
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<BirthdayProvider>(context);
    final selDate = provider.selectedDate;
    final selectedDateString =
        '${kMonthNamesShort[selDate.month - 1]} ${selDate.day}';

    return Scaffold(
      backgroundColor: AppColors.creamBg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header ──────────────────────────────────────────
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  GestureDetector(
                    onTap: () => _showSavedBirthdaysSheet(context),
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.cardBg,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.accentBorder, width: 2.0),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.accentBorder.withValues(alpha: 0.15),
                            offset: const Offset(3, 3),
                            blurRadius: 0,
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(4.0),
                      child: ClipOval(
                        child: Image.asset(
                          'assets/icon/saengil_alrim_logo.png',
                          width: 50,
                          height: 50,
                          fit: BoxFit.cover,
                          errorBuilder: (context, e, st) => Container(
                            width: 50,
                            height: 50,
                            color: AppColors.primaryPink,
                            alignment: Alignment.center,
                            child: const Text('🎂', style: TextStyle(fontSize: 26)),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14.0),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '생일알림',
                          style: AppStyles.titleHandwritten.copyWith(
                            fontSize: 28.0,
                            height: 1.1,
                          ),
                        ),
                        Text(
                          'saengil alrim',
                          style: AppStyles.captionBubbly.copyWith(
                            fontWeight: FontWeight.bold,
                            letterSpacing: 2.5,
                            color: AppColors.textLight,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16.0),

              // ── Permission banners ───────────────────────────────
              if (_missingPermissions.contains(MissingPermission.notifications))
                _PermissionBanner(
                  icon: Icons.notifications_off_rounded,
                  title: 'Notification Permission Required',
                  message:
                      'Alarm notifications are blocked. Tap to grant permission — this is required to see alarms on the lock screen.',
                  color: const Color(0xFFE8F4FD),
                  borderColor: const Color(0xFF4D96FF),
                  onTap: () async {
                    await PermissionService().requestNotificationPermission();
                  },
                ),

              if (_missingPermissions.contains(MissingPermission.batteryOptimization))
                _PermissionBanner(
                  icon: Icons.battery_alert_rounded,
                  title: 'Battery Optimization Active',
                  message:
                      'Your phone may kill alarms in the background. Tap to fix — this is required for reliable birthday alarms.',
                  color: const Color(0xFFFFEDD5),
                  borderColor: const Color(0xFFFF922B),
                  onTap: () async {
                    await PermissionService().requestIgnoreBatteryOptimizations();
                  },
                ),

              if (_missingPermissions.contains(MissingPermission.exactAlarm))
                _PermissionBanner(
                  icon: Icons.alarm_off_rounded,
                  title: 'Exact Alarm Permission Needed',
                  message:
                      'Without this, alarms may fire late or not at all. Tap to open Settings and allow exact alarms.',
                  color: const Color(0xFFFFE5E5),
                  borderColor: Colors.redAccent,
                  onTap: () async {
                    await PermissionService().requestExactAlarmPermission();
                  },
                ),

              if (_missingPermissions.contains(MissingPermission.oemBatterySettings))
                _OemBatteryBanner(
                  permissionService: PermissionService(),
                  onDismissed: _checkPermissions,
                ),

              if (_missingPermissions.isNotEmpty) const SizedBox(height: 8),

              // ── Calendar ─────────────────────────────────────────
              const FunkyCalendar(),
              const SizedBox(height: 24.0),

              // ── Birthdays on selected date ────────────────────────
              Row(
                children: [
                  const Text('📍', style: TextStyle(fontSize: 20.0)),
                  const SizedBox(width: 6.0),
                  Text(
                    'Birthdays on $selectedDateString',
                    style: AppStyles.titleHandwritten.copyWith(fontSize: 20.0),
                  ),
                ],
              ),
              const SizedBox(height: 12.0),

              if (provider.isLoading)
                const Center(child: CircularProgressIndicator())
              else if (provider.birthdaysForSelectedDate.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                      vertical: 24.0, horizontal: 16.0),
                  decoration: AppStyles.funkyCardDecoration(
                    color: AppColors.cardBg,
                    borderRadius: 18.0,
                  ),
                  child: Column(
                    children: [
                      const Text('🧸', style: TextStyle(fontSize: 32.0)),
                      const SizedBox(height: 8.0),
                      Text(
                        'No birthdays today',
                        style: AppStyles.bodyBubbly.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColors.textLight,
                        ),
                      ),
                      const Text(
                        'No birthdays on this day.',
                        style: AppStyles.captionBubbly,
                      ),
                    ],
                  ),
                )
              else
                ...provider.birthdaysForSelectedDate
                    .map((b) => BirthdayCard(birthday: b)),

              const SizedBox(height: 24.0),

              // ── This & next month birthdays ───────────────────────
              Builder(builder: (context) {
                final now = DateTime.now();
                final thisMonthName = kMonthNamesShort[now.month - 1];
                final nextMonthName =
                    kMonthNamesShort[now.month == 12 ? 0 : now.month];
                return Row(
                  children: [
                    const Icon(Icons.cake_rounded,
                        size: 20.0, color: AppColors.textDark),
                    const SizedBox(width: 8.0),
                    Text(
                      '$thisMonthName & $nextMonthName Birthdays',
                      style:
                          AppStyles.titleHandwritten.copyWith(fontSize: 20.0),
                    ),
                  ],
                );
              }),
              const SizedBox(height: 12.0),

              if (provider.isLoading)
                const Center(child: CircularProgressIndicator())
              else if (provider.twoMonthBirthdays.isEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24.0),
                    child: Text(
                      'No birthdays this month or next.',
                      style: AppStyles.captionBubbly,
                    ),
                  ),
                )
              else
                ...provider.twoMonthBirthdays
                    .map((b) => BirthdayCard(birthday: b)),

              const SizedBox(height: 80.0),
            ],
          ),
        ),
      ),
      floatingActionButton: Container(
        width: 55,
        height: 55,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.black, width: 2.5),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color.fromARGB(255, 181, 244, 181),
              Color.fromARGB(255, 219, 245, 155),
              Color.fromARGB(255, 246, 219, 157),
            ],
          ),
          boxShadow: const [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 8,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: FloatingActionButton(
          onPressed: () => _showAddBirthdaySheet(context),
          elevation: 0,
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.black,
          shape: const CircleBorder(),
          child: Image.asset(
            'assets/icon/add.png',
            width: 24,
            height: 24,
            fit: BoxFit.contain,
            errorBuilder: (context, e, st) => const Icon(Icons.add, size: 28),
          ),
        ),
      ),
    );
  }
}

// ── Permission banner widget ──────────────────────────────────────────────────
class _PermissionBanner extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final Color color;
  final Color borderColor;
  final VoidCallback onTap;

  const _PermissionBanner({
    required this.icon,
    required this.title,
    required this.message,
    required this.color,
    required this.borderColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor, width: 1.5),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: borderColor, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppStyles.bodyBubblyBold.copyWith(
                      fontSize: 13,
                      color: AppColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    message,
                    style: AppStyles.captionBubbly.copyWith(
                      color: AppColors.textDark,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.arrow_forward_ios_rounded,
                size: 14, color: borderColor),
          ],
        ),
      ),
    );
  }
}

// ── OEM battery settings banner ───────────────────────────────────────────────
// Shown on Xiaomi, Samsung, Huawei, Oppo, Vivo, OnePlus devices where the
// standard battery optimization exemption is not enough — these OEMs have
// additional proprietary "autostart" or "background app" managers that
// silently kill the AlarmService before it can fire.
//
// Since there is no Android API to detect whether autostart is enabled,
// the user dismisses this banner manually with the × button once they have
// completed the step. The dismissal is persisted in SharedPreferences.
class _OemBatteryBanner extends StatefulWidget {
  final PermissionService permissionService;
  /// Called after the user dismisses so the parent can re-check permissions.
  final VoidCallback onDismissed;

  const _OemBatteryBanner({
    required this.permissionService,
    required this.onDismissed,
  });

  @override
  State<_OemBatteryBanner> createState() => _OemBatteryBannerState();
}

class _OemBatteryBannerState extends State<_OemBatteryBanner> {
  String _label = 'Autostart / Background Settings';

  @override
  void initState() {
    super.initState();
    widget.permissionService.oemBatterySettingsLabel().then((label) {
      if (mounted) setState(() => _label = label);
    });
  }

  Future<void> _openSettings() async {
    await widget.permissionService.openOemBatterySettings();
  }

  Future<void> _dismiss() async {
    await widget.permissionService.dismissOemBanner();
    widget.onDismissed();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3CD),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE6A817), width: 1.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Icon(Icons.phone_android_rounded,
                color: Color(0xFFE6A817), size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: GestureDetector(
              onTap: _openSettings,
              behavior: HitTestBehavior.opaque,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Enable Autostart / Background Access',
                          style: AppStyles.bodyBubblyBold.copyWith(
                            fontSize: 13,
                            color: AppColors.textDark,
                          ),
                        ),
                      ),
                      // Small arrow hint
                      const Icon(Icons.arrow_forward_ios_rounded,
                          size: 13, color: Color(0xFFE6A817)),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Your device ($_label) may silently block background '
                    'alarms. Tap here to open the setting and allow this app '
                    'to run in the background, then tap × when done.',
                    style: AppStyles.captionBubbly.copyWith(
                      color: AppColors.textDark,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 4),
          // Dismiss button — clearly separated from the settings tap area
          GestureDetector(
            onTap: _dismiss,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: const Color(0xFFE6A817).withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close_rounded,
                  size: 16, color: Color(0xFFB87A00)),
            ),
          ),
        ],
      ),
    );
  }
}
