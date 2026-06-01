import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/birthday_service.dart';
import '../widgets/app_styles.dart';
import '../widgets/cute_sticker.dart';
import 'birthday_detail_screen.dart';

// ── Bottom-sheet entry point (called from HomeScreen) ─────────────────────────
class SavedBirthdaysSheet extends StatelessWidget {
  final ScrollController scrollController;
  const SavedBirthdaysSheet({super.key, required this.scrollController});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.creamBg,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(28.0),
          topRight: Radius.circular(28.0),
        ),
        border: Border(
          top: BorderSide(color: AppColors.accentBorder, width: 3.0),
        ),
      ),
      child: Column(
        children: [
          // ── Drag handle + title ──────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Column(
              children: [
                // Drag handle
                Center(
                  child: Container(
                    width: 50,
                    height: 5,
                    decoration: BoxDecoration(
                      color: AppColors.accentBorder.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Saved Birthdays',
                      style:
                          AppStyles.titleHandwritten.copyWith(fontSize: 22),
                    ),
                    Consumer<BirthdayProvider>(
                      builder: (context, provider, _) => Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.primaryPink,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: AppColors.accentBorder, width: 1.5),
                        ),
                        child: Text(
                          '${provider.birthdays.length} saved',
                          style: AppStyles.bodyBubblyBold
                              .copyWith(fontSize: 13),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // ── List ──────────────────────────────────────────────────────
          Expanded(
            child: Consumer<BirthdayProvider>(
              builder: (context, provider, _) {
                if (provider.isLoading) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (provider.birthdays.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('🎂',
                            style: TextStyle(fontSize: 48)),
                        const SizedBox(height: 12),
                        Text(
                          '저장된 생일이 없어요',
                          style: AppStyles.bodyBubblyBold
                              .copyWith(color: AppColors.textLight),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '홈에서 + 버튼으로 추가해보세요',
                          style: AppStyles.captionBubbly,
                        ),
                      ],
                    ),
                  );
                }

                // Sort by upcoming birthday (days until)
                final sorted =
                    List<FriendBirthday>.from(provider.birthdays)
                      ..sort((a, b) => a.daysUntil.compareTo(b.daysUntil));

                return ListView.builder(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                  itemCount: sorted.length,
                  itemBuilder: (context, index) {
                    return _SavedBirthdayTile(birthday: sorted[index]);
                  },
                );
              },
            ),
          ),

          // ── Cloud connect button ───────────────────────────────────────
          Padding(
            padding: const EdgeInsets.only(bottom: 28),
            child: GestureDetector(
              onTap: () {
                // TODO: implement cloud connection
              },
              child: Text(
                'Connect to Cloud',
                style: AppStyles.captionBubbly.copyWith(
                  color: Colors.grey,
                  decoration: TextDecoration.underline,
                  decorationColor: Colors.grey,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Individual tile ───────────────────────────────────────────────────────────
class _SavedBirthdayTile extends StatelessWidget {
  final FriendBirthday birthday;
  const _SavedBirthdayTile({required this.birthday});

  @override
  Widget build(BuildContext context) {
    final b = birthday;
    final themeColor = AppColors.getRandomPastel(b.avatarColorIndex);

    final String dDayLabel =
        b.isToday ? '🎉 오늘이에요!' : 'D-${b.daysUntil}';

    final Color dDayColor = b.isToday
        ? AppColors.primaryPink
        : (b.daysUntil <= 7
            ? AppColors.secondaryApricot
            : AppColors.pastelMint);

    return GestureDetector(
      onTap: () {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          enableDrag: true,
          backgroundColor: Colors.transparent,
          builder: (_) => BirthdayDetailSheet(birthdayId: b.id),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: AppStyles.funkyCardDecoration(
          color: AppColors.cardBg,
          borderRadius: 16,
        ),
        child: Row(
          children: [
            // Avatar
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: themeColor,
                shape: BoxShape.circle,
                border: Border.all(
                    color: AppColors.accentBorder, width: 1.5),
              ),
              alignment: Alignment.center,
              child: CuteSticker(sticker: b.sticker, size: 26),
            ),
            const SizedBox(width: 12),

            // Name + date
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    b.name,
                    style:
                        AppStyles.bodyBubblyBold.copyWith(fontSize: 15),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      const Icon(Icons.cake_rounded,
                          size: 12, color: AppColors.textLight),
                      const SizedBox(width: 4),
                      Text(
                        '${kMonthNamesShort[b.month - 1]} ${b.day}'
                        '${b.birthYear != null ? ' · ${b.birthYear}년생' : ''}',
                        style: AppStyles.captionBubbly,
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // D-day badge
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: dDayColor,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: AppColors.accentBorder, width: 1.5),
              ),
              child: Text(
                dDayLabel,
                style:
                    AppStyles.bodyBubblyBold.copyWith(fontSize: 12),
              ),
            ),

            const SizedBox(width: 8),
            const Icon(Icons.chevron_right_rounded,
                size: 18, color: AppColors.textLight),
          ],
        ),
      ),
    );
  }
}
