import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/friend_birthday.dart';
import '../providers/birthday_provider.dart';
import '../utils/styles.dart';
import '../widgets/custom_button.dart';
import '../widgets/confetti_particles.dart';
import '../widgets/cute_sticker.dart';
import 'add_birthday_view.dart';

class BirthdayDetailView extends StatefulWidget {
  final String birthdayId;

  const BirthdayDetailView({
    super.key,
    required this.birthdayId,
  });

  @override
  State<BirthdayDetailView> createState() => _BirthdayDetailViewState();
}

class _BirthdayDetailViewState extends State<BirthdayDetailView> {
  final _taskController = TextEditingController();
  late TextEditingController _notesController;
  bool _isEditingNotes = false;

  double _lastProgress = 0.0;
  bool _triggerConfetti = false;
  bool _hasBurstedOnBirthday = false;

  @override
  void initState() {
    super.initState();
    // Notes controller will be initialized dynamically in build once provider loads
    _notesController = TextEditingController();
  }

  @override
  void dispose() {
    _taskController.dispose();
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
        title: Text(
          'Delete Reminder? 😢',
          style: AppStyles.titleHandwritten.copyWith(fontSize: 18.0),
        ),
        content: Text(
          'Are you sure you want to remove ${birthday.name}\'s birthday alarm?',
          style: AppStyles.bodyBubbly,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              'No, Keep it!',
              style: AppStyles.bodyBubblyBold.copyWith(color: AppColors.textLight),
            ),
          ),
          CustomButton(
            text: 'Yes, Delete',
            onPressed: () {
              Provider.of<BirthdayProvider>(context, listen: false).deleteBirthday(birthday.id);
              Navigator.of(ctx).pop(); // Close dialog
              Navigator.of(context).pop(); // Back to home
            },
            color: Colors.redAccent.withValues(alpha: 0.3),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<BirthdayProvider>(context);
    final birthdayIndex = provider.birthdays.indexWhere((b) => b.id == widget.birthdayId);

    // Handle case where item might be deleted
    if (birthdayIndex == -1) {
      return Scaffold(
        backgroundColor: AppColors.creamBg,
        body: Center(
          child: Text('Birthday not found!', style: AppStyles.bodyBubbly),
        ),
      );
    }

    final FriendBirthday b = provider.birthdays[birthdayIndex];
    final themeColor = AppColors.getRandomPastel(b.avatarColorIndex);

    // Set notes text initially if editing is not active
    if (!_isEditingNotes) {
      _notesController.text = b.notes;
    }

    // Trigger confetti on 100% completion
    final double currentProgress = b.taskProgress;
    if (currentProgress == 1.0 && _lastProgress < 1.0 && b.tasks.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        setState(() {
          _triggerConfetti = true;
        });
        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted) {
            setState(() {
              _triggerConfetti = false;
            });
          }
        });
      });
    }
    _lastProgress = currentProgress;

    // Trigger confetti on birthday load
    if (b.isToday && !_hasBurstedOnBirthday) {
      _hasBurstedOnBirthday = true;
      _triggerConfetti = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted) {
            setState(() {
              _triggerConfetti = false;
            });
          }
        });
      });
    }

    // Format D-Day
    String dDayText;
    Color dDayBg;
    if (b.isToday) {
      dDayText = 'Happy Birthday! 🥳 D-Day';
      dDayBg = AppColors.primaryPink;
    } else {
      dDayText = 'D-${b.daysUntil} until birthday';
      dDayBg = b.daysUntil <= 7 ? AppColors.secondaryApricot : AppColors.pastelMint;
    }

    return ConfettiOverlay(
      trigger: _triggerConfetti,
      child: Scaffold(
      backgroundColor: AppColors.creamBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textDark),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Friend Profile',
          style: AppStyles.titleHandwritten.copyWith(fontSize: 20.0),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined, color: Colors.greenAccent, size: 28.0),
            onPressed: () {
              Navigator.of(context).pop(); // Close the detail view
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (context) => AddBirthdayView(birthdayToEdit: b),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 28.0),
            onPressed: () => _confirmDelete(context, b),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Polaroid / Sticker style Top profile card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20.0),
              decoration: AppStyles.journalPageDecoration,
              child: Column(
                children: [
                  // Cute avatar circle
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: themeColor,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.accentBorder, width: 2.5),
                    ),
                    alignment: Alignment.center,
                    child: CuteSticker(
                      sticker: b.sticker,
                      size: 44.0,
                    ),
                  ),
                  const SizedBox(height: 12.0),
                  // Name
                  Text(
                    b.name,
                    style: AppStyles.titleHandwritten.copyWith(fontSize: 26.0),
                  ),
                  const SizedBox(height: 6.0),
                  // Korean/English Date and optional age
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.cake_rounded, color: AppColors.primaryPink, size: 18.0),
                      const SizedBox(width: 6.0),
                      Text(
                        (() {
                          final List<String> monthNames = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
                          return '${monthNames[b.month - 1]} ${b.day}';
                        })(),
                        style: AppStyles.bodyBubblyBold.copyWith(fontSize: 16.0),
                      ),
                      if (b.birthYear != null) ...[
                        const SizedBox(width: 8.0),
                        Text(
                          '(Born ${b.birthYear}, Turning ${b.ageTurning})',
                          style: AppStyles.captionBubbly.copyWith(
                            color: AppColors.textDark,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 12.0),
                  // Countdown Bubble
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                    decoration: AppStyles.funkyCardDecoration(
                      color: dDayBg,
                      borderRadius: 12.0,
                    ),
                    child: Text(
                      dDayText,
                      style: AppStyles.bodyBubblyBold.copyWith(fontSize: 14.0),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24.0),

            // Checklist Section
            Text(
              'Preparation Checklist 📝',
              style: AppStyles.titleHandwritten.copyWith(fontSize: 20.0),
            ),
            const SizedBox(height: 10.0),
            Container(
              padding: const EdgeInsets.all(16.0),
              decoration: AppStyles.funkyCardDecoration(
                color: AppColors.cardBg,
                borderRadius: 20.0,
              ),
              child: Column(
                children: [
                  // Progress display
                  if (b.tasks.isNotEmpty) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Prep Progress',
                          style: AppStyles.captionBubbly.copyWith(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          '${(b.taskProgress * 100).toInt()}% Done',
                          style: AppStyles.captionBubbly.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppColors.primaryPink,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8.0),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10.0),
                      child: Container(
                        height: 10.0,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: AppColors.accentBorder.withValues(alpha: 0.1),
                          border: Border.all(color: AppColors.accentBorder, width: 1.5),
                          borderRadius: BorderRadius.circular(10.0),
                        ),
                        alignment: Alignment.centerLeft,
                        child: FractionallySizedBox(
                          widthFactor: b.taskProgress,
                          child: Container(
                            decoration: BoxDecoration(
                              color: AppColors.pastelMint,
                              borderRadius: BorderRadius.circular(8.0),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16.0),
                    const Divider(color: AppColors.accentBorder, thickness: 1.5),
                  ],

                  // Task items list
                  if (b.tasks.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16.0),
                      child: Text(
                        'No prep tasks yet! Add some below ⬇️',
                        style: AppStyles.captionBubbly.copyWith(fontStyle: FontStyle.italic),
                      ),
                    )
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: b.tasks.length,
                      itemBuilder: (context, idx) {
                        final task = b.tasks[idx];
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6.0),
                          child: Row(
                            children: [
                              // Funky custom checkbox
                              GestureDetector(
                                onTap: () => provider.toggleTask(b.id, task.id),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 150),
                                  width: 24,
                                  height: 24,
                                  decoration: BoxDecoration(
                                    color: task.isCompleted ? AppColors.pastelMint : Colors.white,
                                    borderRadius: BorderRadius.circular(6.0),
                                    border: Border.all(
                                      color: AppColors.accentBorder,
                                      width: 2.0,
                                    ),
                                  ),
                                  child: task.isCompleted
                                      ? const Icon(
                                          Icons.check_rounded,
                                          size: 18.0,
                                          color: AppColors.textDark,
                                        )
                                      : null,
                                ),
                              ),
                              const SizedBox(width: 12.0),
                              // Task Title
                              Expanded(
                                child: Text(
                                  task.title,
                                  style: AppStyles.bodyBubbly.copyWith(
                                    decoration: task.isCompleted ? TextDecoration.lineThrough : null,
                                    color: task.isCompleted ? AppColors.textLight : AppColors.textDark,
                                    fontWeight: task.isCompleted ? FontWeight.normal : FontWeight.bold,
                                  ),
                                ),
                              ),
                              // Delete task icon
                              IconButton(
                                icon: const Icon(Icons.close_rounded, color: Colors.grey, size: 20.0),
                                onPressed: () => provider.deleteTask(b.id, task.id),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                            ],
                          ),
                        );
                      },
                    ),

                  const SizedBox(height: 12.0),
                  // Add Task Input Row
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _taskController,
                          style: AppStyles.captionBubbly.copyWith(color: AppColors.textDark, fontSize: 13.0),
                          decoration: InputDecoration(
                            hintText: 'Add new preparation step...',
                            hintStyle: AppStyles.captionBubbly.copyWith(fontSize: 12.0),
                            fillColor: AppColors.creamBg,
                            filled: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10.0),
                              borderSide: const BorderSide(color: AppColors.accentBorder, width: 1.5),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10.0),
                              borderSide: const BorderSide(color: AppColors.accentBorder, width: 2.0),
                            ),
                          ),
                          onSubmitted: (val) {
                            if (val.trim().isNotEmpty) {
                              provider.addTask(b.id, val.trim());
                              _taskController.clear();
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 8.0),
                      IconButton(
                        onPressed: () {
                          if (_taskController.text.trim().isNotEmpty) {
                            provider.addTask(b.id, _taskController.text.trim());
                            _taskController.clear();
                          }
                        },
                        icon: const Icon(Icons.add_circle_outline_rounded, color: AppColors.primaryPink, size: 30.0),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24.0),

            // Alarm Settings Section
            Text(
              'Alarms & Reminders ⏰',
              style: AppStyles.titleHandwritten.copyWith(fontSize: 20.0),
            ),
            const SizedBox(height: 10.0),
            Container(
              padding: const EdgeInsets.all(16.0),
              decoration: AppStyles.funkyCardDecoration(
                color: AppColors.cardBg,
                borderRadius: 20.0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // D-Day alarm toggle
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Birthday Alarm 🎂', style: AppStyles.bodyBubblyBold.copyWith(fontSize: 13.0)),
                          Text('Fires on the actual birthday', style: AppStyles.captionBubbly),
                        ],
                      ),
                      Switch(
                        value: b.enableDDayAlarm,
                        activeThumbColor: AppColors.pastelLavender,
                        activeTrackColor: AppColors.primaryPink,
                        onChanged: (v) => provider.updateBirthday(b.copyWith(enableDDayAlarm: v)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Divider(color: AppColors.accentBorder, thickness: 1.0),
                  const SizedBox(height: 8),
                  // Advance reminder toggle
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Advance Reminder 🎁', style: AppStyles.bodyBubblyBold.copyWith(fontSize: 13.0)),
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
                        onChanged: (v) => provider.updateBirthday(b.copyWith(enableThreeDaysAlarm: v)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Divider(color: AppColors.accentBorder, thickness: 1.0),
                  const SizedBox(height: 8),
                  // Alarm time display
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Alarm Time ⏰', style: AppStyles.bodyBubblyBold.copyWith(fontSize: 13.0)),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.pastelMint,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.accentBorder, width: 1.5),
                        ),
                        child: Text(
                          b.dDayAlarmTimeStr,
                          style: AppStyles.bodyBubblyBold.copyWith(fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                  if (b.dDayRingtoneName != null) ...[
                    const SizedBox(height: 8),
                    const Divider(color: AppColors.accentBorder, thickness: 1.0),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Text('🎵', style: TextStyle(fontSize: 16)),
                        const SizedBox(width: 8),
                        Text('Ringtone: ', style: AppStyles.bodyBubblyBold.copyWith(fontSize: 13.0)),
                        Text(b.dDayRingtoneName!, style: AppStyles.captionBubbly.copyWith(color: AppColors.textDark)),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24.0),

            // Notes Section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Gift Ideas & Notes 💡',
                  style: AppStyles.titleHandwritten.copyWith(fontSize: 20.0),
                ),
                TextButton.icon(
                  onPressed: () async {
                    if (_isEditingNotes) {
                      // Save notes
                      final updatedBirthday = b.copyWith(notes: _notesController.text.trim());
                      await provider.updateBirthday(updatedBirthday);
                    }
                    setState(() {
                      _isEditingNotes = !_isEditingNotes;
                    });
                  },
                  icon: Icon(
                    _isEditingNotes ? Icons.check_rounded : Icons.edit_rounded,
                    size: 16.0,
                    color: AppColors.primaryPink,
                  ),
                  label: Text(
                    _isEditingNotes ? 'Save' : 'Edit',
                    style: AppStyles.bodyBubblyBold.copyWith(color: AppColors.primaryPink, fontSize: 13.0),
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
                      style: AppStyles.bodyBubbly.copyWith(fontStyle: FontStyle.italic),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        hintText: 'Write down gift plans or ideas...',
                      ),
                    )
                  : Text(
                      b.notes.isEmpty ? 'No notes yet. Tap edit to write ideas! 📝' : b.notes,
                      style: AppStyles.bodyBubbly.copyWith(
                        fontStyle: FontStyle.italic,
                        height: 1.4,
                      ),
                    ),
            ),
            const SizedBox(height: 40.0),
          ],
        ),
      ),
    ),);
  }
}
