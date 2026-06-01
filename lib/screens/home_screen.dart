import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/birthday_service.dart';
import '../widgets/app_styles.dart';
import '../widgets/birthday_card.dart';
import '../widgets/funky_calendar.dart';
import 'add_birthday_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  void _showAddBirthdaySheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const AddBirthdayScreen(),
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
              // ── Header ──
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
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
                        errorBuilder: (_, e, st) => Container(
                          width: 50,
                          height: 50,
                          color: AppColors.primaryPink,
                          alignment: Alignment.center,
                          child: const Text('🎂', style: TextStyle(fontSize: 26)),
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
              const SizedBox(height: 24.0),

              // ── Calendar ──
              const FunkyCalendar(),
              const SizedBox(height: 24.0),

              // ── Birthdays on selected date ──
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

              // ── Upcoming Birthdays ──
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
            errorBuilder: (_, e, st) =>
                const Icon(Icons.add, size: 28),
          ),
        ),
      ),
    );
  }
}
