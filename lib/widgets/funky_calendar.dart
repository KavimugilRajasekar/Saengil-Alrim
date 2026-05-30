import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/birthday_provider.dart';
import '../utils/styles.dart';
import 'cute_sticker.dart';

class FunkyCalendar extends StatefulWidget {
  const FunkyCalendar({super.key});

  @override
  State<FunkyCalendar> createState() => _FunkyCalendarState();
}

class _FunkyCalendarState extends State<FunkyCalendar> {
  late DateTime _currentMonth;

  @override
  void initState() {
    super.initState();
    _currentMonth = DateTime.now();
  }

  void _previousMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1, 1);
    });
  }

  void _nextMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1, 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    final birthdayProvider = Provider.of<BirthdayProvider>(context);
    final birthdays = birthdayProvider.birthdays;

    // Get calendar details
    final int year = _currentMonth.year;
    final int month = _currentMonth.month;

    // First day of month
    final DateTime firstDayOfMonth = DateTime(year, month, 1);
    // Number of days in the month
    final int daysInMonth = DateTime(year, month + 1, 0).day;
    // Weekday offset of first day (1 = Mon, 7 = Sun)
    // Adjust it so Sunday is 0 or Monday is 0. Let's make Monday index 0 for Korean style.
    final int firstWeekdayOffset = firstDayOfMonth.weekday - 1; // 0 to 6

    // Total grid cells needed (offset + days)
    final int totalGridCells = firstWeekdayOffset + daysInMonth;
    final int rowsCount = (totalGridCells / 7).ceil();

    final List<String> weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    // English Month names mapping
    final List<String> months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];

    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: AppStyles.journalPageDecoration,
      child: Column(
        children: [
          // Month Navigator Bar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Previous button
              _buildNavButton(
                icon: Icons.arrow_back_ios_new_rounded,
                onTap: _previousMonth,
              ),
              // Current Month Title
              Column(
                children: [
                  Text(
                    months[month - 1],
                    style: AppStyles.titleHandwritten.copyWith(fontSize: 22.0),
                  ),
                  Text(
                    '$year',
                    style: AppStyles.captionBubbly.copyWith(
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2.0,
                    ),
                  ),
                ],
              ),
              // Next button
              _buildNavButton(
                icon: Icons.arrow_forward_ios_rounded,
                onTap: _nextMonth,
              ),
            ],
          ),
          const SizedBox(height: 16.0),

          // Weekdays header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: weekdays.map((day) {
              final isWeekend = day == 'Sat' || day == 'Sun';
              return Expanded(
                child: Center(
                  child: Text(
                    day[0], // Display M, T, W, T, F, S, S
                    style: AppStyles.captionBubbly.copyWith(
                      fontWeight: FontWeight.bold,
                      color: isWeekend
                          ? (day == 'Sun' ? AppColors.pastelLavender : AppColors.secondaryApricot)
                          : AppColors.textDark,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 8.0),

          // Calendar Grid
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 8.0,
              crossAxisSpacing: 8.0,
              childAspectRatio: 1.0,
            ),
            itemCount: rowsCount * 7,
            itemBuilder: (context, index) {
              final int dayNumber = index - firstWeekdayOffset + 1;
              final bool isCurrentMonthDay = dayNumber > 0 && dayNumber <= daysInMonth;

              if (!isCurrentMonthDay) {
                return const SizedBox.shrink(); // Empty space for offset
              }

              final DateTime cellDate = DateTime(year, month, dayNumber);
              final bool isSelected = birthdayProvider.selectedDate.year == cellDate.year &&
                  birthdayProvider.selectedDate.month == cellDate.month &&
                  birthdayProvider.selectedDate.day == cellDate.day;

              // Check if anyone has birthday on this month/day
              final dateBirthdays = birthdays.where((b) => b.month == month && b.day == dayNumber).toList();
              final hasBirthday = dateBirthdays.isNotEmpty;

              return GestureDetector(
                onTap: () {
                  birthdayProvider.setSelectedDate(cellDate);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.primaryPink.withValues(alpha: 0.3)
                        : (hasBirthday ? AppColors.pastelYellow.withValues(alpha: 0.5) : Colors.transparent),
                    borderRadius: BorderRadius.circular(12.0),
                    border: Border.all(
                      color: isSelected
                          ? AppColors.accentBorder
                          : (hasBirthday ? AppColors.accentBorder.withValues(alpha: 0.5) : Colors.transparent),
                      width: isSelected ? 2.0 : 1.0,
                    ),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Date Number (shifted to top-left if birthday sticker is present)
                      Positioned(
                        top: 4,
                        left: 4,
                        child: Text(
                          '$dayNumber',
                          style: AppStyles.dateText.copyWith(
                            fontSize: 12.0,
                            color: isSelected
                                ? AppColors.textDark
                                : AppColors.textDark.withValues(alpha: 0.7),
                          ),
                        ),
                      ),
                      // Cute sticker/emoji overlay for birthday
                      if (hasBirthday)
                        Positioned(
                          bottom: 2,
                          right: 2,
                          child: CuteSticker(
                            sticker: dateBirthdays.first.sticker,
                            size: 14.0,
                          ),
                        ),
                      // If there is more than 1 birthday, show small badge
                      if (dateBirthdays.length > 1)
                        Positioned(
                          top: 2,
                          right: 2,
                          child: Container(
                            padding: const EdgeInsets.all(2.0),
                            decoration: BoxDecoration(
                              color: AppColors.primaryPink,
                              shape: BoxShape.circle,
                              border: Border.all(color: AppColors.accentBorder, width: 1.0),
                            ),
                            child: Text(
                              '+${dateBirthdays.length - 1}',
                              style: const TextStyle(
                                fontSize: 8.0,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textDark,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildNavButton({required IconData icon, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12.0),
      child: Container(
        padding: const EdgeInsets.all(8.0),
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          borderRadius: BorderRadius.circular(12.0),
          border: Border.all(color: AppColors.accentBorder, width: 2.0),
          boxShadow: [
            BoxShadow(
              color: AppColors.accentBorder.withValues(alpha: 0.1),
              offset: const Offset(2, 2),
              blurRadius: 0,
            ),
          ],
        ),
        child: Icon(
          icon,
          size: 16.0,
          color: AppColors.textDark,
        ),
      ),
    );
  }
}
