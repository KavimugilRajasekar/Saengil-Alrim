import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import '../services/birthday_service.dart';
import '../widgets/app_styles.dart';
import '../widgets/cute_sticker.dart';

class AddBirthdayScreen extends StatefulWidget {
  const AddBirthdayScreen({
    super.key,
    this.birthdayToEdit,
    this.initialDate,
    this.scrollController,
  });
  final FriendBirthday? birthdayToEdit;
  final DateTime? initialDate;
  final ScrollController? scrollController;

  @override
  State<AddBirthdayScreen> createState() => _AddBirthdayScreenState();
}

class _AddBirthdayScreenState extends State<AddBirthdayScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _notesController = TextEditingController();
  final _yearController = TextEditingController();

  int _selectedMonth = DateTime.now().month;
  int _selectedDay = DateTime.now().day;
  String _selectedSticker = 'assets/sticker/birthday-cake.png';
  int _selectedColorIndex = 0;

  bool _enableDDayAlarm = true;
  bool _enableReminderAlarm = true;
  int _reminderDays = 3;
  TimeOfDay _dDayAlarmTime = const TimeOfDay(hour: 9, minute: 0);
  String? _selectedDDayRingtonePath;
  String? _selectedDDayRingtoneName;
  TimeOfDay _advanceAlarmTime = const TimeOfDay(hour: 9, minute: 0);
  String? _selectedAdvanceRingtonePath;
  String? _selectedAdvanceRingtoneName;

  // Tracks whether we've already applied last-record defaults (new form only)
  bool _defaultsLoaded = false;

  late AnimationController _saveButtonController;
  late FixedExtentScrollController _monthScrollController;
  late FixedExtentScrollController _dayScrollController;

  static const List<String> _assetStickers = [
    'assets/sticker/birthday-cake.png',
    'assets/sticker/birthday-cake_1.png',
    'assets/sticker/cake.png',
    'assets/sticker/cake_1.png',
    'assets/sticker/cake_2.png',
    'assets/sticker/cake_3.png',
    'assets/sticker/cupcake.png',
    'assets/sticker/pie.png',
    'assets/sticker/cat.png',
    'assets/sticker/chick.png',
    'assets/sticker/koala.png',
    'assets/sticker/penguin.png',
    'assets/sticker/monkey.png',
    'assets/sticker/mouse.png',
    'assets/sticker/elephant.png',
    'assets/sticker/giraffe.png',
    'assets/sticker/crocodile.png',
    'assets/sticker/dinosaur.png',
    'assets/sticker/dinosaur_1.png',
    'assets/sticker/stegosaurus.png',
    'assets/sticker/crow.png',
    'assets/sticker/jellyfish.png',
    'assets/sticker/flower.png',
    'assets/sticker/flower-pot.png',
    'assets/sticker/tulips.png',
    'assets/sticker/magic.png',
    'assets/sticker/drawing.png',
    'assets/sticker/glasses.png',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.birthdayToEdit != null) {
      final b = widget.birthdayToEdit!;
      _nameController.text = b.name;
      _notesController.text = b.notes;
      _selectedMonth = b.month;
      _selectedDay = b.day;
      if (b.birthYear != null) _yearController.text = b.birthYear.toString();
      _selectedSticker = b.sticker;
      _selectedColorIndex = b.avatarColorIndex;
      _enableDDayAlarm = b.enableDDayAlarm;
      _enableReminderAlarm = b.enableThreeDaysAlarm;
      _reminderDays = b.customAlarmDays.clamp(1, 14);
      _dDayAlarmTime = _parseTime(b.dDayAlarmTimeStr);
      _selectedDDayRingtonePath = b.dDayRingtonePath;
      _selectedDDayRingtoneName = b.dDayRingtoneName;
      _advanceAlarmTime = _parseTime(b.advanceAlarmTimeStr);
      _selectedAdvanceRingtonePath = b.advanceRingtonePath;
      _selectedAdvanceRingtoneName = b.advanceRingtoneName;
    } else if (widget.initialDate != null) {
      _selectedMonth = widget.initialDate!.month;
      _selectedDay = widget.initialDate!.day;
    }
    _saveButtonController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
      lowerBound: 0.0,
      upperBound: 0.06,
    );
    _monthScrollController =
        FixedExtentScrollController(initialItem: _selectedMonth - 1);
    _dayScrollController =
        FixedExtentScrollController(initialItem: _selectedDay - 1);
  }

  TimeOfDay _parseTime(String timeStr) {
    try {
      final parts = timeStr.split(':');
      if (parts.length == 2) {
        return TimeOfDay(
            hour: int.parse(parts[0]), minute: int.parse(parts[1]));
      }
    } catch (_) {}
    return const TimeOfDay(hour: 9, minute: 0);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Only run once, and only when creating a new birthday (not editing).
    if (_defaultsLoaded || widget.birthdayToEdit != null) return;
    _defaultsLoaded = true;

    // Pull the most recently added birthday and use its alarm settings
    // as defaults so the user doesn't have to re-pick the same ringtone
    // and time every time they add a new entry.
    final provider = Provider.of<BirthdayProvider>(context, listen: false);
    if (provider.birthdays.isEmpty) return;

    // Use the last entry in the list (most recently added)
    final last = provider.birthdays.last;

    setState(() {
      _enableDDayAlarm = last.enableDDayAlarm;
      _enableReminderAlarm = last.enableThreeDaysAlarm;
      _reminderDays = last.customAlarmDays.clamp(1, 14);
      _dDayAlarmTime = _parseTime(last.dDayAlarmTimeStr);
      _selectedDDayRingtonePath = last.dDayRingtonePath;
      _selectedDDayRingtoneName = last.dDayRingtoneName;
      _advanceAlarmTime = _parseTime(last.advanceAlarmTimeStr);
      _selectedAdvanceRingtonePath = last.advanceRingtonePath;
      _selectedAdvanceRingtoneName = last.advanceRingtoneName;
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _notesController.dispose();
    _yearController.dispose();
    _saveButtonController.dispose();
    _monthScrollController.dispose();
    _dayScrollController.dispose();
    super.dispose();
  }

  Future<void> _pickFromGallery() async {
    final picker = ImagePicker();
    final XFile? picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
      maxWidth: 512,
      maxHeight: 512,
    );
    if (picked != null) setState(() => _selectedSticker = picked.path);
  }

  /// Pick a ringtone / audio file from device storage.
  Future<void> _pickRingtone({required bool isDDay}) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.audio,
      allowMultiple: false,
    );
    if (result != null && result.files.isNotEmpty) {
      final file = result.files.first;
      final path = file.path;
      final name = file.name.replaceAll(RegExp(r'\.[^.]+$'), '');
      if (path != null) {
        setState(() {
          if (isDDay) {
            _selectedDDayRingtonePath = path;
            _selectedDDayRingtoneName = name;
          } else {
            _selectedAdvanceRingtonePath = path;
            _selectedAdvanceRingtoneName = name;
          }
        });
      }
    }
  }

  String _formatTimeOfDay(TimeOfDay tod) =>
      '${tod.hour.toString().padLeft(2, '0')}:${tod.minute.toString().padLeft(2, '0')}';

  String _formatDisplayTime(TimeOfDay tod) {
    final h = tod.hourOfPeriod == 0 ? 12 : tod.hourOfPeriod;
    final m = tod.minute.toString().padLeft(2, '0');
    final period = tod.period == DayPeriod.am ? 'AM' : 'PM';
    return '$h:$m $period';
  }

  Future<void> _pickTime({required bool isDDay}) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isDDay ? _dDayAlarmTime : _advanceAlarmTime,
      builder: (context, child) => Theme(
        data: ThemeData.light().copyWith(
          colorScheme: const ColorScheme.light(
            primary: AppColors.primaryPink,
            onSurface: AppColors.textDark,
          ),
          textButtonTheme: TextButtonThemeData(
            style: TextButton.styleFrom(
              foregroundColor: AppColors.textDark,
              textStyle: AppStyles.bodyBubblyBold,
            ),
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        if (isDDay) {
          _dDayAlarmTime = picked;
        } else {
          _advanceAlarmTime = picked;
        }
      });
    }
  }

  void _saveBirthday() {
    _saveButtonController
        .forward()
        .then((_) => _saveButtonController.reverse());
    if (!_formKey.currentState!.validate()) return;

    // Require at least one ringtone when alarms are enabled
    if (_enableDDayAlarm && _selectedDDayRingtonePath == null) {
      _showRingtoneRequiredDialog('Birthday Alarm');
      return;
    }
    if (_enableReminderAlarm && _selectedAdvanceRingtonePath == null) {
      _showRingtoneRequiredDialog('Advance Reminder');
      return;
    }

    final provider = Provider.of<BirthdayProvider>(context, listen: false);
    final isEditing = widget.birthdayToEdit != null;
    final id = isEditing
        ? widget.birthdayToEdit!.id
        : DateTime.now().millisecondsSinceEpoch.toString();

    int? year;
    if (_yearController.text.trim().isNotEmpty) {
      year = int.tryParse(_yearController.text.trim());
    }

    final birthday = FriendBirthday(
      id: id,
      name: _nameController.text.trim(),
      month: _selectedMonth,
      day: _selectedDay,
      birthYear: year,
      sticker: _selectedSticker,
      notes: _notesController.text.trim(),
      avatarColorIndex: _selectedColorIndex,
      enableDDayAlarm: _enableDDayAlarm,
      enableThreeDaysAlarm: _enableReminderAlarm,
      customAlarmDays: _reminderDays,
      dDayAlarmTimeStr: _formatTimeOfDay(_dDayAlarmTime),
      dDayRingtonePath: _selectedDDayRingtonePath,
      dDayRingtoneName: _selectedDDayRingtoneName,
      advanceAlarmTimeStr: _formatTimeOfDay(_advanceAlarmTime),
      advanceRingtonePath: _selectedAdvanceRingtonePath,
      advanceRingtoneName: _selectedAdvanceRingtoneName,
    );

    if (isEditing) {
      provider.updateBirthday(birthday);
    } else {
      provider.addBirthday(birthday);
    }

    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${_nameController.text.trim()}\'s Birthday ${isEditing ? 'updated' : 'saved'}',
          style: const TextStyle(fontFamily: AppStyles.bubblyFont, color: Colors.black,),
        ),
        backgroundColor: AppColors.primaryPink,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AppColors.accentBorder, width: 1.5),
        ),
      ),
    );
  }

  void _showRingtoneRequiredDialog(String alarmType) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: AppColors.creamBg,
        title: Text(
          'Ringtone Required',
          style: AppStyles.bodyBubblyBold.copyWith(fontSize: 16),
        ),
        content: Text(
          'Please select a ringtone for the $alarmType before saving.',
          style: AppStyles.bodyBubbly,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('OK',
                style: AppStyles.bodyBubblyBold
                    .copyWith(color: AppColors.primaryPink)),
          ),
        ],
      ),
    );
  }

  // ── Helpers ──

  Widget _sectionLabel(String text, IconData icon) => Text(
        text,
        style: const TextStyle(
          fontFamily: AppStyles.handwritingFont,
          fontSize: 20.0,
          fontWeight: FontWeight.w800,
          color: AppColors.textDark,
          letterSpacing: 0.1,
        ),
      );

  InputDecoration _inputDecoration({required String hintText}) =>
      InputDecoration(
        hintText: hintText,
        hintStyle: AppStyles.captionBubbly,
        fillColor: AppColors.cardBg,
        filled: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14.0),
          borderSide:
              const BorderSide(color: AppColors.accentBorder, width: 2.0),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14.0),
          borderSide:
              const BorderSide(color: AppColors.accentBorder, width: 2.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14.0),
          borderSide: const BorderSide(color: Colors.redAccent, width: 2.0),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14.0),
          borderSide: const BorderSide(color: Colors.redAccent, width: 2.5),
        ),
      );

  // ── Circle Date Selector ──
  Widget _buildCircleDateSelector() {
    final maxDays = DateTime(DateTime.now().year, _selectedMonth + 1, 0).day;

    return Container(
      height: 160,
      decoration: AppStyles.funkyCardDecoration(
          color: AppColors.cardBg, borderRadius: 18.0),
      child: Row(
        children: [
          // Month wheel
          Expanded(
            flex: 3,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Selection highlight
                Center(
                  child: Container(
                    height: 44,
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      color: AppColors.primaryPink.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: AppColors.accentBorder, width: 1.5),
                    ),
                  ),
                ),
                ListWheelScrollView.useDelegate(
                  controller: _monthScrollController,
                  itemExtent: 44,
                  perspective: 0.003,
                  diameterRatio: 1.8,
                  physics: const FixedExtentScrollPhysics(),
                  onSelectedItemChanged: (idx) {
                    setState(() {
                      _selectedMonth = idx + 1;
                      final newMax =
                          DateTime(DateTime.now().year, _selectedMonth + 1, 0)
                              .day;
                      if (_selectedDay > newMax) {
                        _selectedDay = newMax;
                        _dayScrollController.jumpToItem(_selectedDay - 1);
                      }
                    });
                  },
                  childDelegate: ListWheelChildBuilderDelegate(
                    childCount: 12,
                    builder: (context, idx) {
                      final isSelected = _selectedMonth == idx + 1;
                      return Center(
                        child: Text(
                          kMonthNamesFull[idx],
                          style: AppStyles.bodyBubbly.copyWith(
                            fontSize: isSelected ? 14 : 12,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.w500,
                            color: isSelected
                                ? AppColors.textDark
                                : AppColors.textLight,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          // Divider
          Container(
            width: 1.5,
            height: 100,
            color: AppColors.accentBorder.withValues(alpha: 0.3),
          ),
          // Day wheel
          Expanded(
            flex: 1,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Center(
                  child: Container(
                    height: 44,
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      color: AppColors.primaryPink.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: AppColors.accentBorder, width: 1.5),
                    ),
                  ),
                ),
                ListWheelScrollView.useDelegate(
                  controller: _dayScrollController,
                  itemExtent: 44,
                  perspective: 0.003,
                  diameterRatio: 1.8,
                  physics: const FixedExtentScrollPhysics(),
                  onSelectedItemChanged: (idx) {
                    setState(() => _selectedDay = idx + 1);
                  },
                  childDelegate: ListWheelChildBuilderDelegate(
                    childCount: maxDays,
                    builder: (context, idx) {
                      final isSelected = _selectedDay == idx + 1;
                      return Center(
                        child: Text(
                          '${idx + 1}',
                          style: AppStyles.bodyBubbly.copyWith(
                            fontSize: isSelected ? 16 : 13,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.w500,
                            color: isSelected
                                ? AppColors.textDark
                                : AppColors.textLight,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Ringtone picker row ──
  Widget _ringtonePickerRow({
    required String? selectedPath,
    required String? selectedName,
    required bool isDDay,
  }) {
    final hasRingtone = selectedPath != null;
    return GestureDetector(
      onTap: () => _pickRingtone(isDDay: isDDay),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: hasRingtone
              ? AppColors.pastelMint
              : AppColors.secondaryApricot,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: hasRingtone
                ? AppColors.accentBorder
                : AppColors.accentBorder.withValues(alpha: 0.5),
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Icon(
              hasRingtone
                  ? Icons.music_note_rounded
                  : Icons.music_off_rounded,
              size: 20,
              color: AppColors.textDark,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    hasRingtone ? selectedName! : 'No ringtone',
                    style: AppStyles.bodyBubblyBold.copyWith(fontSize: 13),
                    softWrap: true,
                    maxLines: 3,
                    overflow: TextOverflow.visible,
                  ),
                  Text(
                    hasRingtone
                        ? 'Tap to change'
                        : 'Tap to pick from device',
                    style: AppStyles.captionBubbly,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Time chip ──
  Widget _timeChip(TimeOfDay time, {required bool isDDay}) {
    return GestureDetector(
      onTap: () => _pickTime(isDDay: isDDay),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isDDay ? 'Alarm Time' : 'Reminder Time',
            style: AppStyles.bodyBubblyBold.copyWith(fontSize: 13.0),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.pastelMint,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.accentBorder, width: 1.5),
            ),
            child: Text(
              _formatDisplayTime(time),
              style: AppStyles.bodyBubblyBold.copyWith(fontSize: 15),
            ),
          ),
        ],
      ),
    );
  }

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
      padding: EdgeInsets.only(
        left: 20.0,
        right: 20.0,
        top: 24.0,
        bottom: MediaQuery.of(context).viewInsets.bottom + 32.0,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          controller: widget.scrollController,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
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
              const SizedBox(height: 18.0),

              // Title row
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppColors.getRandomPastel(_selectedColorIndex),
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: AppColors.accentBorder, width: 2.0),
                    ),
                    alignment: Alignment.center,
                    child: CuteSticker(sticker: _selectedSticker, size: 26),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    widget.birthdayToEdit != null
                        ? 'Edit Birthday'
                        : 'New Birthday',
                    style: AppStyles.titleHandwritten
                        .copyWith(fontSize: 22.0),
                  ),
                ],
              ),
              const SizedBox(height: 24.0),

              // ── Name ──
              _sectionLabel('Name', Icons.person_outline_rounded),
              const SizedBox(height: 8.0),
              TextFormField(
                controller: _nameController,
                style: AppStyles.bodyBubbly,
                decoration: _inputDecoration(hintText: 'e.g. Ji-soo'),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Please enter a name'
                    : null,
              ),
              const SizedBox(height: 20.0),

              // ── Date ──
              _sectionLabel('Birthday Date', Icons.calendar_today_rounded),
              const SizedBox(height: 8.0),
              _buildCircleDateSelector(),
              const SizedBox(height: 14.0),
              TextFormField(
                controller: _yearController,
                keyboardType: TextInputType.number,
                style: AppStyles.bodyBubbly,
                decoration: _inputDecoration(
                    hintText: 'Birth Year (optional, e.g. 2002)'),
                validator: (v) {
                  if (v != null && v.isNotEmpty) {
                    final y = int.tryParse(v);
                    if (y == null || y < 1900 || y > DateTime.now().year) {
                      return 'Enter a valid year';
                    }
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20.0),

              // ── Card Colour ──
              _sectionLabel('Card Colour', Icons.palette_outlined),
              const SizedBox(height: 10.0),
              SizedBox(
                height: 44,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: 6,
                  itemBuilder: (context, i) {
                    final c = AppColors.getRandomPastel(i);
                    final isSel = _selectedColorIndex == i;
                    return GestureDetector(
                      onTap: () =>
                          setState(() => _selectedColorIndex = i),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        margin: const EdgeInsets.only(right: 10),
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: c,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.accentBorder,
                            width: isSel ? 3.0 : 1.5,
                          ),
                          boxShadow: isSel
                              ? [
                                  BoxShadow(
                                    color: AppColors.accentBorder
                                        .withValues(alpha: 0.2),
                                    blurRadius: 4,
                                    offset: const Offset(2, 2),
                                  )
                                ]
                              : null,
                        ),
                        child: isSel
                            ? const Icon(Icons.check_rounded,
                                color: AppColors.textDark, size: 18)
                            : null,
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 20.0),

              // ── Sticker Picker ──
              _sectionLabel('Birthday Sticker', Icons.emoji_emotions_outlined),
              const SizedBox(height: 10.0),
              Container(
                height: 168,
                padding: const EdgeInsets.all(10.0),
                decoration: AppStyles.funkyCardDecoration(
                    color: AppColors.cardBg, borderRadius: 16.0),
                child: GridView.builder(
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 7,
                    crossAxisSpacing: 8.0,
                    mainAxisSpacing: 8.0,
                  ),
                  itemCount: _assetStickers.length,
                  itemBuilder: (context, idx) {
                    final s = _assetStickers[idx];
                    final isSel = _selectedSticker == s;
                    return GestureDetector(
                      onTap: () => setState(() => _selectedSticker = s),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 120),
                        decoration: BoxDecoration(
                          color: isSel
                              ? AppColors.getRandomPastel(
                                      _selectedColorIndex)
                                  .withValues(alpha: 0.5)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(10.0),
                          border: Border.all(
                            color: isSel
                                ? AppColors.accentBorder
                                : Colors.transparent,
                            width: 1.5,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: CuteSticker(sticker: s, size: 28.0),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 10.0),
              GestureDetector(
                onTap: _pickFromGallery,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 12.0),
                  decoration: AppStyles.funkyCardDecoration(
                    color: AppColors.secondaryApricot,
                    borderRadius: 14.0,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.add_photo_alternate_rounded,
                          color: AppColors.textDark, size: 20),
                      const SizedBox(width: 8),
                      Text('Use Photo from Gallery',
                          style: AppStyles.bodyBubblyBold
                              .copyWith(fontSize: 13.0)),
                      if (!_selectedSticker.startsWith('assets/')) ...[
                        const SizedBox(width: 8),
                        ClipOval(
                          child: Image.file(
                            File(_selectedSticker),
                            width: 24,
                            height: 24,
                            fit: BoxFit.cover,
                            errorBuilder: (_, e, st) => const SizedBox(),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20.0),

              // ── Alarms & Reminders ──
              _sectionLabel('Alarms & Reminders', Icons.alarm_rounded),
              const SizedBox(height: 10.0),
              _buildAlarmSection(),
              const SizedBox(height: 20.0),

              // ── Notes ──
              _sectionLabel('Gift Ideas & Notes', Icons.edit_note_rounded),
              const SizedBox(height: 8.0),
              TextFormField(
                controller: _notesController,
                maxLines: 2,
                style: AppStyles.bodyBubbly,
                decoration: _inputDecoration(
                    hintText: 'e.g. Loves ribbons, wants a skin-care set...'),
              ),
              const SizedBox(height: 28.0),

              // ── Save Button ──
              AnimatedBuilder(
                animation: _saveButtonController,
                builder: (context, child) => Transform.scale(
                  scale: 1.0 - _saveButtonController.value,
                  child: child,
                ),
                child: GestureDetector(
                  onTapDown: (_) => _saveButtonController.forward(),
                  onTapUp: (_) {
                    _saveButtonController.reverse();
                    _saveBirthday();
                  },
                  onTapCancel: () => _saveButtonController.reverse(),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 18.0),
                    decoration: AppStyles.funkyButtonDecoration(
                      color: AppColors.primaryPink,
                      borderRadius: 22.0,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.cake_rounded,
                            color: AppColors.textDark, size: 22),
                        const SizedBox(width: 10),
                        Text(
                          'Save Birthday',
                          style: AppStyles.titleHandwritten.copyWith(
                              fontSize: 20.0, color: AppColors.textDark),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Center(
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text('Cancel',
                      style: AppStyles.bodyBubbly
                          .copyWith(color: AppColors.textLight)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Alarm section ──
  Widget _buildAlarmSection() {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: AppStyles.funkyCardDecoration(
          color: AppColors.cardBg, borderRadius: 18.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Birthday Alarm root ─────────────────────────────────────
          _alarmToggleRow(
            label: 'Birthday Alarm',
            sublabel: 'Fires on the actual birthday',
            value: _enableDDayAlarm,
            onChanged: (v) => setState(() => _enableDDayAlarm = v),
          ),
          _AnimatedTreeBranch(
            visible: _enableDDayAlarm,
            children: [
              _treeChild(
                isLast: false,
                child: _timeChip(_dDayAlarmTime, isDDay: true),
              ),
              _treeChild(
                isLast: true,
                child: _ringtoneNode(
                  selectedPath: _selectedDDayRingtonePath,
                  selectedName: _selectedDDayRingtoneName,
                  isDDay: true,
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),
          const Divider(color: AppColors.accentBorder, thickness: 1.0),
          const SizedBox(height: 14),

          // ── Advance Reminder root ───────────────────────────────────
          _alarmToggleRow(
            label: 'Advance Reminder',
            sublabel: 'Remind me days before birthday',
            value: _enableReminderAlarm,
            onChanged: (v) => setState(() => _enableReminderAlarm = v),
          ),
          _AnimatedTreeBranch(
            visible: _enableReminderAlarm,
            children: [
              _treeChild(
                isLast: false,
                child: _daysBefore(),
              ),
              _treeChild(
                isLast: false,
                child: _timeChip(_advanceAlarmTime, isDDay: false),
              ),
              _treeChild(
                isLast: true,
                child: _ringtoneNode(
                  selectedPath: _selectedAdvanceRingtonePath,
                  selectedName: _selectedAdvanceRingtoneName,
                  isDDay: false,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Days-before row + slider (used as a tree child).
  Widget _daysBefore() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Days Before',
                style: AppStyles.bodyBubblyBold.copyWith(fontSize: 13.0)),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.pastelLavender,
                borderRadius: BorderRadius.circular(20),
                border:
                    Border.all(color: AppColors.accentBorder, width: 1.5),
              ),
              child: Text(
                '$_reminderDays day${_reminderDays > 1 ? 's' : ''}',
                style: AppStyles.bodyBubblyBold.copyWith(fontSize: 12),
              ),
            ),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: AppColors.primaryPink,
            inactiveTrackColor:
                AppColors.primaryPink.withValues(alpha: 0.3),
            thumbColor: AppColors.pastelLavender,
            overlayColor: AppColors.pastelLavender.withValues(alpha: 0.2),
            thumbShape:
                const RoundSliderThumbShape(enabledThumbRadius: 10),
            trackHeight: 4,
          ),
          child: Slider(
            value: _reminderDays.toDouble(),
            min: 1,
            max: 14,
            divisions: 13,
            onChanged: (v) => setState(() => _reminderDays = v.round()),
          ),
        ),
      ],
    );
  }

  /// Ringtone node — the picker row, with the warning as its own sub-branch.
  Widget _ringtoneNode({
    required String? selectedPath,
    required String? selectedName,
    required bool isDDay,
  }) {
    final missing = selectedPath == null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Ringtone',
            style: AppStyles.bodyBubblyBold.copyWith(fontSize: 13.0)),
        const SizedBox(height: 5),
        _ringtonePickerRow(
          selectedPath: selectedPath,
          selectedName: selectedName,
          isDDay: isDDay,
        ),
        // Warning is a sub-branch of the ringtone card
        _AnimatedTreeBranch(
          visible: missing,
          children: [
            _treeChild(
              isLast: true,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFEEEE),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: Colors.redAccent.withValues(alpha: 0.4),
                      width: 1.2),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline_rounded,
                        size: 13, color: Colors.redAccent),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        'A ringtone is required to save',
                        style: AppStyles.captionBubbly.copyWith(
                            color: Colors.redAccent,
                            fontStyle: FontStyle.italic),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// The toggle header row for each alarm.
  Widget _alarmToggleRow({
    required String label,
    required String sublabel,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Dot indicator
        AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: value ? const Color(0xFF1B5E20) : AppColors.textLight,
            shape: BoxShape.circle,
            border: Border.all(
              color: value ? const Color(0xFF1B5E20) : AppColors.accentBorder,
              width: 1.5,
            ),
            boxShadow: value
                ? [
                    BoxShadow(
                      color: const Color(0xFF1B5E20).withValues(alpha: 0.35),
                      blurRadius: 6,
                      spreadRadius: 1,
                    )
                  ]
                : null,
          ),
        ),
        const SizedBox(width: 10),
        // Label + sublabel — Expanded so text wraps instead of overflowing
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: AppStyles.bodyBubblyBold.copyWith(fontSize: 13.0)),
              Text(sublabel,
                  style: AppStyles.captionBubbly,
                  softWrap: true),
            ],
          ),
        ),
        const SizedBox(width: 4),
        // Switch — fixed width, never squeezed
        Material(
          color: Colors.transparent,
          child: Switch(
            value: value,
            activeThumbColor: AppColors.pastelLavender,
            activeTrackColor: AppColors.primaryPink,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  /// Wraps a child with a light-grey tree connector line — no gap in the stem.
  Widget _treeChild({required Widget child, required bool isLast}) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Line column spans full IntrinsicHeight — stem is unbroken
          SizedBox(
            width: 24,
            child: CustomPaint(
              painter: _TreeLinePainter(isLast: isLast),
            ),
          ),
          const SizedBox(width: 8),
          // Top padding = elbowY - half of label line height ≈ 12px
          // so the label baseline aligns with the elbow at 20px
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 12.0, bottom: 4.0),
              child: child,
            ),
          ),
        ],
      ),
    );
  }
}

/// Animated expand/collapse wrapper — clips height only, no horizontal shift.
class _AnimatedTreeBranch extends StatefulWidget {
  final bool visible;
  final List<Widget> children;
  const _AnimatedTreeBranch(
      {required this.visible, required this.children});

  @override
  State<_AnimatedTreeBranch> createState() => _AnimatedTreeBranchState();
}

class _AnimatedTreeBranchState extends State<_AnimatedTreeBranch>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
      value: widget.visible ? 1.0 : 0.0,
    );
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOutCubic);
  }

  @override
  void didUpdateWidget(_AnimatedTreeBranch old) {
    super.didUpdateWidget(old);
    if (widget.visible != old.visible) {
      widget.visible ? _ctrl.forward() : _ctrl.reverse();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizeTransition(
      sizeFactor: _anim,
      axisAlignment: -1.0, // expand from top
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: widget.children,
      ),
    );
  }
}

/// Draws light-grey vertical + horizontal connector lines for the tree.
/// The elbow always points to a fixed distance from the top (where the label is).
class _TreeLinePainter extends CustomPainter {
  final bool isLast;
  static const _treeColor = Color(0xFFBDBDBD); // light grey
  // Fixed Y offset from top of the child where the label sits
  static const double _elbowY = 20.0;

  const _TreeLinePainter({required this.isLast});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = _treeColor
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    const stemX = 10.0;

    // Vertical stem — from top to elbowY for last node, full height otherwise
    canvas.drawLine(
      const Offset(stemX, 0),
      Offset(stemX, isLast ? _elbowY : size.height),
      paint,
    );

    // Horizontal elbow at fixed label height
    canvas.drawLine(
      const Offset(stemX, _elbowY),
      Offset(size.width, _elbowY),
      paint,
    );
  }

  @override
  bool shouldRepaint(_TreeLinePainter old) => old.isLast != isLast;
}
