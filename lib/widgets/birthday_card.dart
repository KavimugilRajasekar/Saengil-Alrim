import 'package:flutter/material.dart';
import '../services/birthday_service.dart';
import '../widgets/app_styles.dart';
import '../screens/birthday_detail_screen.dart';
import 'cute_sticker.dart';

class BirthdayCard extends StatefulWidget {
  final FriendBirthday birthday;
  const BirthdayCard({super.key, required this.birthday});

  @override
  State<BirthdayCard> createState() => _BirthdayCardState();
}

class _BirthdayCardState extends State<BirthdayCard>
    with SingleTickerProviderStateMixin {
  late double _scale;
  late AnimationController _controller;

  @override
  void initState() {
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 70),
      lowerBound: 0.0,
      upperBound: 0.05,
    )..addListener(() => setState(() {}));
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

    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) {
        _controller.reverse();
        Navigator.of(context).push(
          CuteRouteTransition(
            page: BirthdayDetailScreen(birthdayId: b.id),
          ),
        );
      },
      onTapCancel: () => _controller.reverse(),
      child: Transform.scale(
        scale: _scale,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12.0, left: 4.0, right: 4.0),
          decoration: AppStyles.funkyCardDecoration(color: AppColors.cardBg),
          clipBehavior: Clip.hardEdge,
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Left date block ──
                Container(
                  width: 62,
                  decoration: BoxDecoration(
                    color: themeColor,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16.0),
                      bottomLeft: Radius.circular(16.0),
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        kMonthNamesShort[b.month - 1].toUpperCase(),
                        style: AppStyles.captionBubbly.copyWith(
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textDark,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${b.day}',
                        style: AppStyles.bodyBubblyBold.copyWith(
                          fontSize: 26.0,
                          height: 1.0,
                          color: AppColors.textDark,
                        ),
                      ),
                      if (b.isToday) ...[
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 5, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.cardBg.withValues(alpha: 0.7),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'TODAY',
                            style: AppStyles.captionBubbly.copyWith(
                              fontSize: 7.5,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textDark,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                // ── Main content ──
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14.0, vertical: 12.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Avatar
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            color: themeColor.withValues(alpha: 0.5),
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: AppColors.accentBorder, width: 1.5),
                          ),
                          alignment: Alignment.center,
                          child: CuteSticker(sticker: b.sticker, size: 24.0),
                        ),
                        const SizedBox(width: 12.0),

                        // Name + badges + notes
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                b.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppStyles.titleHandwritten
                                    .copyWith(fontSize: 18.0),
                              ),
                              if (b.birthYear != null) ...[
                                const SizedBox(height: 5.0),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 7.0, vertical: 2.5),
                                  decoration: BoxDecoration(
                                    color: AppColors.pastelLavender,
                                    borderRadius: BorderRadius.circular(20.0),
                                    border: Border.all(
                                        color: AppColors.accentBorder,
                                        width: 1.0),
                                  ),
                                  child: Text(
                                    'Turning ${b.ageTurning}',
                                    style: AppStyles.captionBubbly.copyWith(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.textDark),
                                  ),
                                ),
                              ],
                              if (b.notes.isNotEmpty) ...[
                                const SizedBox(height: 5.0),
                                Row(
                                  children: [
                                    const Icon(Icons.notes_rounded,
                                        size: 12, color: AppColors.textLight),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        b.notes,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: AppStyles.captionBubbly.copyWith(
                                            fontStyle: FontStyle.italic),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),

                        // ── Chevron ──
                        const Icon(Icons.chevron_right_rounded,
                            size: 20, color: AppColors.textLight),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
