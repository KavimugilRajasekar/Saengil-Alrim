import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/birthday_service.dart';
import '../widgets/app_styles.dart';
import '../widgets/custom_button.dart';
import '../widgets/confetti_particles.dart';
import '../widgets/cute_sticker.dart';
import 'add_birthday_screen.dart';

// ── Bottom-sheet entry point (used by BirthdayCard) ──────────────────────────
class BirthdayDetailSheet extends StatelessWidget {
  final String birthdayId;
  const BirthdayDetailSheet({super.key, required this.birthdayId});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 1.0,
      minChildSize: 0.0,
      maxChildSize: 1.0,
      snap: true,
      snapSizes: const [0.0, 1.0],
      expand: false,
      builder: (context, scrollController) => _BirthdayDetailBody(
        birthdayId: birthdayId,
        scrollController: scrollController,
      ),
    );
  }
}

// ── Legacy full-screen route (kept for any existing Navigator.push calls) ─────
class BirthdayDetailScreen extends StatelessWidget {
  final String birthdayId;
  const BirthdayDetailScreen({super.key, required this.birthdayId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.creamBg,
      body: SafeArea(
        child: _BirthdayDetailBody(
          birthdayId: birthdayId,
          scrollController: null,
        ),
      ),
    );
  }
}

// ── Shared body ───────────────────────────────────────────────────────────────
class _BirthdayDetailBody extends StatefulWidget {
  final String birthdayId;
  final ScrollController? scrollController;
  const _BirthdayDetailBody(
      {required this.birthdayId, required this.scrollController});

  @override
  State<_BirthdayDetailBody> createState() => _BirthdayDetailBodyState();
}

class _BirthdayDetailBodyState extends State<_BirthdayDetailBody> {
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
                style:
                    AppStyles.bodyBubblyBold.copyWith(color: AppColors.textLight)),
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
    final idx =
        provider.birthdays.indexWhere((b) => b.id == widget.birthdayId);

    if (idx == -1) {
      return Center(
          child: Text('Birthday not found!', style: AppStyles.bodyBubbly));
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
        b.isToday ? 'Happy Birthday!' : 'D-${b.daysUntil} until birthday';
    final Color dDayBg = b.isToday
        ? AppColors.primaryPink
        : (b.daysUntil <= 7
            ? AppColors.secondaryApricot
            : AppColors.pastelMint);

    return ConfettiOverlay(
      trigger: _triggerConfetti,
      child: Container(
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
            // ── Drag handle + title row ──────────────────────────────────
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
              child: Column(
                children: [
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
                        'Friend Profile',
                        style:
                            AppStyles.titleHandwritten.copyWith(fontSize: 22.0),
                      ),
                      Row(
                        children: [
                          // Edit
                          GestureDetector(
                            onTap: () {
                              Navigator.of(context).pop();
                              showModalBottomSheet(
                                context: context,
                                isScrollControlled: true,
                                enableDrag: true,
                                backgroundColor: Colors.transparent,
                                builder: (context) =>
                                    DraggableScrollableSheet(
                                  initialChildSize: 1.0,
                                  minChildSize: 0.0,
                                  maxChildSize: 1.0,
                                  snap: true,
                                  snapSizes: const [0.0, 1.0],
                                  expand: false,
                                  builder: (context, _) =>
                                      AddBirthdayScreen(birthdayToEdit: b),
                                ),
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppColors.pastelMint,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                    color: AppColors.accentBorder, width: 1.5),
                              ),
                              child: const Icon(Icons.edit_outlined,
                                  size: 18, color: AppColors.textDark),
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Delete
                          GestureDetector(
                            onTap: () => _confirmDelete(context, b),
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFE5E5),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                    color: AppColors.accentBorder, width: 1.5),
                              ),
                              child: const Icon(Icons.delete_outline_rounded,
                                  size: 18, color: Colors.redAccent),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // ── Scrollable content ───────────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                controller: widget.scrollController,
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Profile card
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

                    // Alarms
                    Text('Alarms & Reminders',
                        style: AppStyles.titleHandwritten
                            .copyWith(fontSize: 20.0)),
                    const SizedBox(height: 10.0),
                    _AlarmInfoCard(birthday: b),
                    const SizedBox(height: 24.0),

                    // Notes
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Gift Ideas & Notes',
                            style: AppStyles.titleHandwritten
                                .copyWith(fontSize: 20.0)),
                        TextButton.icon(
                          onPressed: () async {
                            if (_isEditingNotes) {
                              await provider.updateBirthday(b.copyWith(
                                  notes: _notesController.text.trim()));
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
                                  ? 'No notes yet. Tap edit to write ideas!'
                                  : b.notes,
                              style: AppStyles.bodyBubbly.copyWith(
                                  fontStyle: FontStyle.italic, height: 1.4),
                            ),
                    ),
                    const SizedBox(height: 28.0),

                    // ── Close ────────────────────────────────────────────
                    Center(
                      child: TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text(
                          'Close',
                          style: AppStyles.bodyBubbly
                              .copyWith(color: AppColors.textLight),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Read-only alarm info card with live countdown ─────────────────────────────
class _AlarmInfoCard extends StatefulWidget {
  final FriendBirthday birthday;
  const _AlarmInfoCard({required this.birthday});

  @override
  State<_AlarmInfoCard> createState() => _AlarmInfoCardState();
}

class _AlarmInfoCardState extends State<_AlarmInfoCard> {
  late final Stream<DateTime> _ticker;

  @override
  void initState() {
    super.initState();
    // Tick every minute so the "X hrs Y min" display stays current
    _ticker = Stream.periodic(
      const Duration(minutes: 1),
      (_) => DateTime.now(),
    ).asBroadcastStream();
  }

  /// Parse "HH:MM" into a TimeOfDay
  TimeOfDay _parseTime(String s) {
    final p = s.split(':');
    return TimeOfDay(hour: int.parse(p[0]), minute: int.parse(p[1]));
  }

  /// Returns a human-readable remaining time string for an alarm that fires
  /// [daysFromNow] days from today at [alarmTime].
  String _remaining(int daysFromNow, TimeOfDay alarmTime) {
    final now = DateTime.now();
    final alarmDt = DateTime(
      now.year,
      now.month,
      now.day + daysFromNow,
      alarmTime.hour,
      alarmTime.minute,
    );
    final diff = alarmDt.difference(now);
    if (diff.isNegative) return 'Passed';
    final d = diff.inDays;
    final h = diff.inHours % 24;
    final m = diff.inMinutes % 60;
    if (d > 0) return '${d}d ${h}h ${m}m';
    if (h > 0) return '${h}h ${m}m';
    return '${m}m';
  }

  Widget _alarmRow({
    required bool enabled,
    required String label,
    required String sublabel,
    required String timeStr,
    required String? ringtoneName,
    required int daysFromNow,
  }) {
    final alarmTime = _parseTime(timeStr);
    final remaining = enabled ? _remaining(daysFromNow, alarmTime) : null;
    final rowColor =
        enabled ? AppColors.pastelMint : AppColors.creamBg;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: rowColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: enabled
              ? AppColors.accentBorder
              : AppColors.accentBorder.withValues(alpha: 0.3),
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          Icon(
            enabled ? Icons.alarm_rounded : Icons.alarm_off_rounded,
            size: 22,
            color: enabled ? AppColors.textDark : AppColors.textLight,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: AppStyles.bodyBubblyBold.copyWith(
                      fontSize: 13,
                      color: enabled
                          ? AppColors.textDark
                          : AppColors.textLight,
                    )),
                Text(sublabel, style: AppStyles.captionBubbly),
                if (enabled) ...[
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      const Icon(Icons.schedule_rounded,
                          size: 11, color: AppColors.textLight),
                      const SizedBox(width: 3),
                      Text(
                        timeStr,
                        style: AppStyles.captionBubbly
                            .copyWith(fontWeight: FontWeight.bold),
                      ),
                      if (ringtoneName != null) ...[
                        const SizedBox(width: 8),
                        const Icon(Icons.music_note_rounded,
                            size: 11, color: AppColors.textLight),
                        const SizedBox(width: 3),
                        Flexible(
                          child: Text(
                            ringtoneName,
                            overflow: TextOverflow.ellipsis,
                            style: AppStyles.captionBubbly,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ],
            ),
          ),
          if (enabled && remaining != null) ...[
            const SizedBox(width: 8),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.cardBg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: AppColors.accentBorder, width: 1.5),
              ),
              child: Column(
                children: [
                  Text(
                    remaining,
                    style: AppStyles.bodyBubblyBold
                        .copyWith(fontSize: 12, color: AppColors.textDark),
                  ),
                  Text('remaining',
                      style: AppStyles.captionBubbly
                          .copyWith(fontSize: 8.5)),
                ],
              ),
            ),
          ] else if (!enabled) ...[
            const SizedBox(width: 8),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.cardBg.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: AppColors.accentBorder.withValues(alpha: 0.3),
                    width: 1.5),
              ),
              child: Text(
                'Off',
                style: AppStyles.captionBubbly.copyWith(
                    fontWeight: FontWeight.bold, color: AppColors.textLight),
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final b = widget.birthday;
    return StreamBuilder<DateTime>(
      stream: _ticker,
      builder: (context, _) {
        final advanceDaysFromNow =
            b.daysUntil - b.customAlarmDays < 0 ? 0 : b.daysUntil - b.customAlarmDays;
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: AppStyles.funkyCardDecoration(
              color: AppColors.cardBg, borderRadius: 20.0),
          child: Column(
            children: [
              _alarmRow(
                enabled: b.enableDDayAlarm,
                label: 'Birthday Alarm',
                sublabel: 'Fires on the actual birthday',
                timeStr: b.dDayAlarmTimeStr,
                ringtoneName: b.dDayRingtoneName,
                daysFromNow: b.daysUntil,
              ),
              const SizedBox(height: 10),
              _alarmRow(
                enabled: b.enableThreeDaysAlarm,
                label: 'Advance Reminder',
                sublabel: b.customAlarmDays == 0
                    ? 'Same day as birthday'
                    : '${b.customAlarmDays} day${b.customAlarmDays > 1 ? 's' : ''} before',
                timeStr: b.advanceAlarmTimeStr,
                ringtoneName: b.advanceRingtoneName,
                daysFromNow: advanceDaysFromNow,
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.info_outline_rounded,
                      size: 12, color: AppColors.textLight),
                  const SizedBox(width: 4),
                  Text(
                    'Edit alarms from the edit screen',
                    style: AppStyles.captionBubbly.copyWith(fontSize: 10.5),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
