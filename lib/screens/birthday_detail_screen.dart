import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/birthday_service.dart';
import '../widgets/app_styles.dart';
import '../widgets/custom_button.dart';
import '../widgets/confetti_particles.dart';
import '../widgets/cute_sticker.dart';
import 'add_birthday_screen.dart';

class BirthdayDetailScreen extends StatefulWidget {
  final String birthdayId;
  const BirthdayDetailScreen({super.key, required this.birthdayId});

  @override
  State<BirthdayDetailScreen> createState() => _BirthdayDetailScreenState();
}

class _BirthdayDetailScreenState extends State<BirthdayDetailScreen> {
  late TextEditingController _notesController;
  bool _isEditingNotes = false;
  bool _triggerConfetti = false;
  bool _hasBurstedOnBirthday = false;

  @override
  void initState() {
    super.initState();
    _notesController = TextEditingController();
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  void _confirmDelete(BuildContext context, FriendBirthday birthday) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.creamBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20.0),
          side: const BorderSide(color: AppColors.accentBorder, width: 2.5),
        ),
        title: Text('Delete Reminder?',
            style: AppStyles.titleHandwritten.copyWith(fontSize: 18.0)),
        content: Text(
          'Are you sure you want to remove ${birthday.name}\'s birthday alarm?',
          style: AppStyles.bodyBubbly,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('No, Keep it!',
                style: AppStyles.bodyBubblyBold
                    .copyWith(color: AppColors.textLight)),
          ),
          CustomButton(
            text: 'Yes, Delete',
            onPressed: () {
              Provider.of<BirthdayProvider>(context, listen: false)
                  .deleteBirthday(birthday.id);
              Navigator.of(ctx).pop();
              Navigator.of(context).pop();
            },
            color: const Color.fromARGB(255, 244, 110, 110),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<BirthdayProvider>(context);
    final idx = provider.birthdays.indexWhere((b) => b.id == widget.birthdayId);

    if (idx == -1) {
      return Scaffold(
        backgroundColor: AppColors.creamBg,
        body: Center(
            child: Text('Birthday not found!', style: AppStyles.bodyBubbly)),
      );
    }

    final FriendBirthday b = provider.birthdays[idx];
    final themeColor = AppColors.getRandomPastel(b.avatarColorIndex);

    if (!_isEditingNotes) _notesController.text = b.notes;

    if (b.isToday && !_hasBurstedOnBirthday) {
      _hasBurstedOnBirthday = true;
      _triggerConfetti = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted) setState(() => _triggerConfetti = false);
        });
      });
    }

    final String dDayText =
        b.isToday ? 'Happy Birthday! 🥳' : 'D-${b.daysUntil} until birthday';
    final Color dDayBg = b.isToday
        ? AppColors.primaryPink
        : (b.daysUntil <= 7 ? AppColors.secondaryApricot : AppColors.pastelMint);

    return ConfettiOverlay(
      trigger: _triggerConfetti,
      child: Scaffold(
        backgroundColor: AppColors.creamBg,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded,
                color: AppColors.textDark),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: Text('Friend Profile',
              style: AppStyles.titleHandwritten.copyWith(fontSize: 20.0)),
          actions: [
            IconButton(
              icon: const Icon(Icons.edit_outlined,
                  color: Colors.greenAccent, size: 28.0),
              onPressed: () {
                Navigator.of(context).pop();
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (context) =>
                      AddBirthdayScreen(birthdayToEdit: b),
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded,
                  color: Colors.redAccent, size: 28.0),
              onPressed: () => _confirmDelete(context, b),
            ),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Profile card ──
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20.0),
                decoration: AppStyles.journalPageDecoration,
                child: Column(
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: themeColor,
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: AppColors.accentBorder, width: 2.5),
                      ),
                      alignment: Alignment.center,
                      child: CuteSticker(sticker: b.sticker, size: 44.0),
                    ),
                    const SizedBox(height: 12.0),
                    Text(b.name,
                        style: AppStyles.titleHandwritten
                            .copyWith(fontSize: 26.0)),
                    const SizedBox(height: 6.0),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.cake_rounded,
                            color: AppColors.primaryPink, size: 18.0),
                        const SizedBox(width: 6.0),
                        Text(
                          '${kMonthNamesShort[b.month - 1]} ${b.day}',
                          style: AppStyles.bodyBubblyBold
                              .copyWith(fontSize: 16.0),
                        ),
                        if (b.birthYear != null) ...[
                          const SizedBox(width: 8.0),
                          Text(
                            '(Born ${b.birthYear}, Turning ${b.ageTurning})',
                            style: AppStyles.captionBubbly.copyWith(
                                color: AppColors.textDark,
                                fontWeight: FontWeight.bold),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 12.0),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16.0, vertical: 8.0),
                      decoration: AppStyles.funkyCardDecoration(
                          color: dDayBg, borderRadius: 12.0),
                      child: Text(dDayText,
                          style: AppStyles.bodyBubblyBold
                              .copyWith(fontSize: 14.0)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24.0),

              // ── Alarms ──
              Text('Alarms & Reminders',
                  style: AppStyles.titleHandwritten.copyWith(fontSize: 20.0)),
              const SizedBox(height: 10.0),
              Container(
                padding: const EdgeInsets.all(16.0),
                decoration: AppStyles.funkyCardDecoration(
                    color: AppColors.cardBg, borderRadius: 20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Birthday Alarm 🎂',
                                style: AppStyles.bodyBubblyBold
                                    .copyWith(fontSize: 13.0)),
                            Text('Fires on the actual birthday',
                                style: AppStyles.captionBubbly),
                          ],
                        ),
                        Switch(
                          value: b.enableDDayAlarm,
                          activeThumbColor: AppColors.pastelLavender,
                          activeTrackColor: AppColors.primaryPink,
                          onChanged: (v) => provider
                              .updateBirthday(b.copyWith(enableDDayAlarm: v)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Divider(
                        color: AppColors.accentBorder, thickness: 1.0),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Advance Reminder 🎁',
                                style: AppStyles.bodyBubblyBold
                                    .copyWith(fontSize: 13.0)),
                            Text(
                              b.customAlarmDays == 0
                                  ? 'Same day as birthday'
                                  : '${b.customAlarmDays} day${b.customAlarmDays > 1 ? 's' : ''} before',
                              style: AppStyles.captionBubbly,
                            ),
                          ],
                        ),
                        Switch(
                          value: b.enableThreeDaysAlarm,
                          activeThumbColor: AppColors.pastelLavender,
                          activeTrackColor: AppColors.primaryPink,
                          onChanged: (v) => provider.updateBirthday(
                              b.copyWith(enableThreeDaysAlarm: v)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Divider(
                        color: AppColors.accentBorder, thickness: 1.0),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Alarm Time ⏰',
                            style: AppStyles.bodyBubblyBold
                                .copyWith(fontSize: 13.0)),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.pastelMint,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: AppColors.accentBorder, width: 1.5),
                          ),
                          child: Text(b.dDayAlarmTimeStr,
                              style: AppStyles.bodyBubblyBold
                                  .copyWith(fontSize: 14)),
                        ),
                      ],
                    ),
                    if (b.dDayRingtoneName != null) ...[
                      const SizedBox(height: 8),
                      const Divider(
                          color: AppColors.accentBorder, thickness: 1.0),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Text('🎵', style: TextStyle(fontSize: 16)),
                          const SizedBox(width: 8),
                          Text('Ringtone: ',
                              style: AppStyles.bodyBubblyBold
                                  .copyWith(fontSize: 13.0)),
                          Text(b.dDayRingtoneName!,
                              style: AppStyles.captionBubbly
                                  .copyWith(color: AppColors.textDark)),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 24.0),

              // ── Notes ──
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Gift Ideas & Notes',
                      style:
                          AppStyles.titleHandwritten.copyWith(fontSize: 20.0)),
                  TextButton.icon(
                    onPressed: () async {
                      if (_isEditingNotes) {
                        await provider.updateBirthday(
                            b.copyWith(notes: _notesController.text.trim()));
                      }
                      setState(() => _isEditingNotes = !_isEditingNotes);
                    },
                    icon: Icon(
                      _isEditingNotes
                          ? Icons.check_rounded
                          : Icons.edit_rounded,
                      size: 16.0,
                      color: AppColors.primaryPink,
                    ),
                    label: Text(
                      _isEditingNotes ? 'Save' : 'Edit',
                      style: AppStyles.bodyBubblyBold.copyWith(
                          color: AppColors.primaryPink, fontSize: 13.0),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10.0),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16.0),
                decoration: AppStyles.funkyCardDecoration(
                  color: AppColors.pastelYellow.withValues(alpha: 0.4),
                  borderRadius: 20.0,
                ),
                child: _isEditingNotes
                    ? TextField(
                        controller: _notesController,
                        maxLines: 4,
                        style: AppStyles.bodyBubbly
                            .copyWith(fontStyle: FontStyle.italic),
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          hintText: 'Write down gift plans or ideas...',
                        ),
                      )
                    : Text(
                        b.notes.isEmpty
                            ? 'No notes yet. Tap edit to write ideas! 📝'
                            : b.notes,
                        style: AppStyles.bodyBubbly.copyWith(
                            fontStyle: FontStyle.italic, height: 1.4),
                      ),
              ),
              const SizedBox(height: 40.0),
            ],
          ),
        ),
      ),
    );
  }
}
