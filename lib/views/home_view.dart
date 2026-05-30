import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/birthday_provider.dart';
import '../utils/styles.dart';
import '../widgets/birthday_card.dart';
import '../widgets/funky_calendar.dart';
import 'add_birthday_view.dart';

class HomeView extends StatelessWidget {
  const HomeView({super.key});

  void _showAddBirthdaySheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const AddBirthdayView(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final birthdayProvider = Provider.of<BirthdayProvider>(context);

    // Filter selected date formatting
    final DateTime selDate = birthdayProvider.selectedDate;
    final List<String> monthNames = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final String selectedDateString = '${monthNames[selDate.month - 1]} ${selDate.day}';

    return Scaffold(
      backgroundColor: AppColors.creamBg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Beautiful Funky Korean Header with Logo
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Cute app logo
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
                        errorBuilder: (context, error, stackTrace) {
                          // Fallback if image asset fails to load
                          return Container(
                            width: 50,
                            height: 50,
                            color: AppColors.primaryPink,
                            alignment: Alignment.center,
                            child: const Text('🎂', style: TextStyle(fontSize: 26)),
                          );
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: 14.0),
                  // App Title
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

              // Custom Sticker Calendar
              const FunkyCalendar(),
              const SizedBox(height: 24.0),

              // Selected Date Birthdays
              Row(
                children: [
                  const Text(
                    '📍',
                    style: TextStyle(fontSize: 20.0),
                  ),
                  const SizedBox(width: 6.0),
                  Text(
                    'Birthdays on $selectedDateString',
                    style: AppStyles.titleHandwritten.copyWith(fontSize: 20.0),
                  ),
                ],
              ),
              const SizedBox(height: 12.0),

              if (birthdayProvider.isLoading)
                const Center(child: CircularProgressIndicator())
              else if (birthdayProvider.birthdaysForSelectedDate.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 24.0, horizontal: 16.0),
                  decoration: AppStyles.funkyCardDecoration(
                    color: AppColors.cardBg,
                    borderRadius: 18.0,
                  ),
                  child: Column(
                    children: [
                      const Text(
                        '🧸',
                        style: TextStyle(fontSize: 32.0),
                      ),
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
                ...birthdayProvider.birthdaysForSelectedDate.map((b) => BirthdayCard(birthday: b)),

              const SizedBox(height: 24.0),

              // Upcoming Birthdays Title
              Row(
                children: [
                  const Text(
                    '🎁',
                    style: TextStyle(fontSize: 20.0),
                  ),
                  const SizedBox(width: 6.0),
                  Text(
                    'Upcoming Birthdays',
                    style: AppStyles.titleHandwritten.copyWith(fontSize: 20.0),
                  ),
                ],
              ),
              const SizedBox(height: 12.0),

              if (birthdayProvider.isLoading)
                const Center(child: CircularProgressIndicator())
              else if (birthdayProvider.birthdays.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 24.0),
                  child: Center(
                    child: Text(
                      'No birthdays registered yet! Tap + to add.',
                      style: AppStyles.captionBubbly,
                    ),
                  ),
                )
              else
                ...birthdayProvider.upcomingBirthdays.map((b) => BirthdayCard(birthday: b)),

              // Extra space at bottom to scroll past FAB
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
      border: Border.all(
        color: Colors.black,
        width: 2.5,
      ),
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color.fromARGB(255, 181, 244, 181), // very light green
          Color.fromARGB(255, 219, 245, 155), // very light yellow
          Color.fromARGB(255, 246, 219, 157), // light gold
        ],
      ),
      boxShadow: [
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
          'assets/icon/user.png',
          width: 24,
          height: 24,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            // Fallback if image asset fails to load
            return const Icon(Icons.add, size: 28);
          },
        ),
      ),
      ),  
    );
  }
}
