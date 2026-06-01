import 'package:flutter/material.dart';
import '../models/friend_birthday.dart';
import '../utils/styles.dart';
import '../utils/cute_route_transition.dart';
import '../views/birthday_detail_view.dart';
import 'cute_sticker.dart';

class BirthdayCard extends StatefulWidget {
  final FriendBirthday birthday;

  const BirthdayCard({
    super.key,
    required this.birthday,
  });

  @override
  State<BirthdayCard> createState() => _BirthdayCardState();
}

class _BirthdayCardState extends State<BirthdayCard> with SingleTickerProviderStateMixin {
  late double _scale;
  late AnimationController _controller;

  @override
  void initState() {
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 70),
      lowerBound: 0.0,
      upperBound: 0.05,
    )..addListener(() {
        setState(() {});
      });
    super.initState();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _scale = 1 - _controller.value;
    final b = widget.birthday;
    final themeColor = AppColors.getRandomPastel(b.avatarColorIndex);

    final List<String> monthNames = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final dateStringStr = '${monthNames[b.month - 1]} ${b.day}';

    // Format D-Day
    String dDayText;
    Color dDayBg;
    if (b.isToday) {
      dDayText = 'D-Day 🎉';
      dDayBg = AppColors.primaryPink;
    } else {
      dDayText = 'D-${b.daysUntil}';
      dDayBg = b.daysUntil <= 7 ? AppColors.secondaryApricot : AppColors.pastelMint;
    }

    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) {
        _controller.reverse();
        Navigator.of(context).push(
          CuteRouteTransition(
            page: BirthdayDetailView(birthdayId: b.id),
          ),
        );
      },
      onTapCancel: () => _controller.reverse(),
      child: Transform.scale(
        scale: _scale,
        child: Container(
          margin: const EdgeInsets.only(bottom: 16.0, left: 4.0, right: 4.0),
          padding: const EdgeInsets.all(16.0),
          decoration: AppStyles.funkyCardDecoration(color: AppColors.cardBg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Cute sticker circular avatar
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: themeColor,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.accentBorder,
                        width: 2.0,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: CuteSticker(
                      sticker: b.sticker,
                      size: 26.0,
                    ),
                  ),
                  const SizedBox(width: 14.0),
                  // Name and Korean/English Date
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          b.name,
                          style: AppStyles.titleHandwritten.copyWith(fontSize: 20.0),
                        ),
                        const SizedBox(height: 4.0),
                        Row(
                          children: [
                            const Icon(
                              Icons.calendar_today_rounded,
                              size: 14.0,
                              color: AppColors.textLight,
                            ),
                            const SizedBox(width: 4.0),
                            Text(
                              dateStringStr,
                              style: AppStyles.captionBubbly.copyWith(
                                color: AppColors.textDark,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (b.birthYear != null) ...[
                              const SizedBox(width: 6.0),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 1.5),
                                decoration: BoxDecoration(
                                  color: AppColors.pastelLavender,
                                  borderRadius: BorderRadius.circular(6.0),
                                  border: Border.all(color: AppColors.accentBorder, width: 1.0),
                                ),
                                child: Text(
                                  'Turning ${b.ageTurning}',
                                  style: AppStyles.captionBubbly.copyWith(
                                    fontSize: 9.0,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textDark,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  // D-Day Bubble Tag
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
                    decoration: AppStyles.funkyCardDecoration(
                      color: dDayBg,
                      borderRadius: 12.0,
                      showBorder: true,
                    ),
                    child: Text(
                      dDayText,
                      style: AppStyles.bodyBubblyBold.copyWith(
                        fontSize: 13.0,
                      ),
                    ),
                  ),
                ],
              ),
              // Notes Preview (if any)
              if (b.notes.isNotEmpty) ...[
                const SizedBox(height: 12.0),
                Text(
                  b.notes,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppStyles.bodyBubbly.copyWith(
                    fontSize: 13.0,
                    color: AppColors.textLight,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
