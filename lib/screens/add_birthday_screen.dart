import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../services/birthday_service.dart';
import '../widgets/app_styles.dart';
import '../widgets/cute_sticker.dart';

class AddBirthdayScreen extends StatefulWidget {
  const AddBirthdayScreen({super.key, this.birthdayToEdit});
  final FriendBirthday? birthdayToEdit;

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

  // Alarm state — kept as plain fields, toggled via setState
  bool _enableDDayAlarm = true;
  bool _enableReminderAlarm = true;
  int _reminderDays = 3;
  TimeOfDay _dDayAlarmTime = const TimeOfDay(hour: 9, minute: 0);
  String? _selectedDDayRingtonePath;
  String? _selectedDDayRingtoneName;
  TimeOfDay _advanceAlarmTime = const TimeOfDay(hour: 9, minute: 0);
  String? _selectedAdvanceRingtonePath;
  String? _selectedAdvanceRingtoneName;

  late AnimationController _saveButtonController;

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

  static const List<Map<String, String>> _ringtones = [
    {'name': 'Default Bell', 'path': 'chime'},
    {'name': 'Fairy Dust', 'path': 'fairy'},
    {'name': 'Music Box', 'path': 'music_box'},
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
      _reminderDays = b.customAlarmDays;
      _dDayAlarmTime = _parseTime(b.dDayAlarmTimeStr);
      _selectedDDayRingtonePath = b.dDayRingtonePath;
      _selectedDDayRingtoneName = b.dDayRingtoneName;
      _advanceAlarmTime = _parseTime(b.advanceAlarmTimeStr);
      _selectedAdvanceRingtonePath = b.advanceRingtonePath;
      _selectedAdvanceRingtoneName = b.advanceRingtoneName;
    }
    _saveButtonController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
      lowerBound: 0.0,
      upperBound: 0.06,
    );
  }

  TimeOfDay _parseTime(String timeStr) {
    try {
      final parts = timeStr.split(':');
      if (parts.length == 2) {
        return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
      }
    } catch (_) {}
    return const TimeOfDay(hour: 9, minute: 0);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _notesController.dispose();
    _yearController.dispose();
    _saveButtonController.dispose();
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
    _saveButtonController.forward().then((_) => _saveButtonController.reverse());
    if (!_formKey.currentState!.validate()) return;

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
          '${_nameController.text.trim()}\'s Birthday ${isEditing ? 'updated' : 'saved'}! 🥳',
          style: const TextStyle(fontFamily: AppStyles.bubblyFont),
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

  // ── Helpers ──

  Widget _sectionLabel(String text) => Text(
        text,
        style: AppStyles.bodyBubblyBold.copyWith(
          fontSize: 14.0,
          color: AppColors.textDark,
          letterSpacing: 0.3,
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

  // ── Ringtone row ──
  Widget _ringtoneRow({
    required String? selectedPath,
    required void Function(String path, String name) onSelect,
  }) {
    return Row(
      children: _ringtones.map((rt) {
        final isSel = selectedPath == rt['path'];
        return Expanded(
          child: GestureDetector(
            onTap: () => onSelect(rt['path']!, rt['name']!),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              margin: const EdgeInsets.only(right: 6),
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
              decoration: BoxDecoration(
                color: isSel ? AppColors.secondaryApricot : AppColors.creamBg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isSel
                      ? AppColors.accentBorder
                      : AppColors.accentBorder.withValues(alpha: 0.4),
                  width: 1.5,
                ),
              ),
              child: Column(
                children: [
                  Text(isSel ? '🔔' : '🔕',
                      style: const TextStyle(fontSize: 16)),
                  const SizedBox(height: 2),
                  Text(
                    rt['name']!,
                    textAlign: TextAlign.center,
                    style: AppStyles.captionBubbly
                        .copyWith(fontSize: 9, color: AppColors.textDark),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  // ── Time chip ──
  Widget _timeChip(TimeOfDay time, {required bool isDDay}) {
    return GestureDetector(
      onTap: () => _pickTime(isDDay: isDDay),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isDDay ? 'D-Day Alarm Time ⏰' : 'Reminder Alarm Time ⏰',
                  style: AppStyles.bodyBubblyBold.copyWith(fontSize: 13.0),
                ),
                Text('Tap to change', style: AppStyles.captionBubbly),
              ],
            ),
          ),
          const SizedBox(width: 8),
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
                        ? 'Edit Birthday ✏️'
                        : 'New Birthday ✨',
                    style:
                        AppStyles.titleHandwritten.copyWith(fontSize: 22.0),
                  ),
                ],
              ),
              const SizedBox(height: 24.0),

              // ── Name ──
              _sectionLabel('Friend\'s Name ✏️'),
              const SizedBox(height: 8.0),
              TextFormField(
                controller: _nameController,
                style: AppStyles.bodyBubbly,
                decoration: _inputDecoration(hintText: 'e.g. Ji-soo 🌸'),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Please enter a name!' : null,
              ),
              const SizedBox(height: 20.0),

              // ── Date ──
              _sectionLabel('Birthday Date 🗓️'),
              const SizedBox(height: 8.0),
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 12.0),
                      decoration: AppStyles.funkyCardDecoration(
                          color: AppColors.cardBg, borderRadius: 14.0),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<int>(
                          value: _selectedMonth,
                          isExpanded: true,
                          icon: const Icon(Icons.keyboard_arrow_down_rounded,
                              color: AppColors.textDark),
                          dropdownColor: AppColors.cardBg,
                          style: AppStyles.bodyBubblyBold,
                          items: List.generate(12, (i) => i + 1).map((m) {
                            return DropdownMenuItem<int>(
                              value: m,
                              child: Text(kMonthNamesFull[m - 1]),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setState(() {
                                _selectedMonth = val;
                                final maxDays = DateTime(
                                        DateTime.now().year, val + 1, 0)
                                    .day;
                                if (_selectedDay > maxDays) {
                                  _selectedDay = maxDays;
                                }
                              });
                            }
                          },
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 1,
                    child: Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 12.0),
                      decoration: AppStyles.funkyCardDecoration(
                          color: AppColors.cardBg, borderRadius: 14.0),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<int>(
                          value: _selectedDay,
                          isExpanded: true,
                          icon: const Icon(Icons.keyboard_arrow_down_rounded,
                              size: 16, color: AppColors.textDark),
                          dropdownColor: AppColors.cardBg,
                          style: AppStyles.bodyBubblyBold,
                          items: List.generate(
                                  DateTime(DateTime.now().year,
                                          _selectedMonth + 1, 0)
                                      .day,
                                  (i) => i + 1)
                              .map((d) => DropdownMenuItem<int>(
                                  value: d, child: Text('$d')))
                              .toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setState(() => _selectedDay = val);
                            }
                          },
                        ),
                      ),
                    ),
                  ),
                ],
              ),
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
                      return 'Enter a valid year!';
                    }
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20.0),

              // ── Card Colour ──
              _sectionLabel('Card Colour 🎨'),
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
                      onTap: () => setState(() => _selectedColorIndex = i),
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
              _sectionLabel('Birthday Sticker 🩷'),
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
                              ? AppColors.getRandomPastel(_selectedColorIndex)
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
              _sectionLabel('Alarms & Reminders 🔔'),
              const SizedBox(height: 10.0),
              _buildAlarmSection(),
              const SizedBox(height: 20.0),

              // ── Notes ──
              _sectionLabel('Gift Ideas & Notes 💌'),
              const SizedBox(height: 8.0),
              TextFormField(
                controller: _notesController,
                maxLines: 2,
                style: AppStyles.bodyBubbly,
                decoration: _inputDecoration(
                    hintText:
                        'e.g. Loves ribbons, wants a skin-care set...'),
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
                        const Text('🎂', style: TextStyle(fontSize: 22)),
                        const SizedBox(width: 10),
                        Text(
                          'Save Birthday',
                          style: AppStyles.titleHandwritten
                              .copyWith(fontSize: 20.0, color: AppColors.textDark),
                        ),
                        const SizedBox(width: 10),
                        const Text('🎀', style: TextStyle(fontSize: 22)),
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

  // ── Alarm section — extracted to its own method so setState rebuilds it cleanly ──
  Widget _buildAlarmSection() {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration:
          AppStyles.funkyCardDecoration(color: AppColors.cardBg, borderRadius: 18.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Birthday (D-Day) Alarm ──
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Birthday Alarm 🎂',
                        style: AppStyles.bodyBubblyBold.copyWith(fontSize: 13.0)),
                    Text('Fires at alarm time on the actual day',
                        style: AppStyles.captionBubbly),
                  ],
                ),
              ),
              // FIX: wrap Switch in Material so it gets its own hit-test zone
              // and is not swallowed by any ancestor GestureDetector.
              Material(
                color: Colors.transparent,
                child: Switch(
                  value: _enableDDayAlarm,
                  activeThumbColor: AppColors.pastelLavender,
                  activeTrackColor: AppColors.primaryPink,
                  onChanged: (v) {
                    setState(() => _enableDDayAlarm = v);
                  },
                ),
              ),
            ],
          ),

          if (_enableDDayAlarm) ...[
            const SizedBox(height: 8),
            _timeChip(_dDayAlarmTime, isDDay: true),
            const SizedBox(height: 8),
            Text('D-Day Ringtone 🎵',
                style: AppStyles.bodyBubblyBold.copyWith(fontSize: 13.0)),
            const SizedBox(height: 8),
            _ringtoneRow(
              selectedPath: _selectedDDayRingtonePath,
              onSelect: (path, name) => setState(() {
                _selectedDDayRingtonePath = path;
                _selectedDDayRingtoneName = name;
              }),
            ),
            if (_selectedDDayRingtonePath == null)
              Padding(
                padding: const EdgeInsets.only(top: 6.0),
                child: Text(
                  'No ringtone selected (system default)',
                  style: AppStyles.captionBubbly
                      .copyWith(fontStyle: FontStyle.italic),
                ),
              ),
          ],

          const SizedBox(height: 12),
          const Divider(color: AppColors.accentBorder, thickness: 1.0),
          const SizedBox(height: 12),

          // ── Advance Reminder ──
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Advance Reminder 🎁',
                        style: AppStyles.bodyBubblyBold.copyWith(fontSize: 13.0)),
                    Text('Remind me days before birthday',
                        style: AppStyles.captionBubbly),
                  ],
                ),
              ),
              Material(
                color: Colors.transparent,
                child: Switch(
                  value: _enableReminderAlarm,
                  activeThumbColor: AppColors.pastelLavender,
                  activeTrackColor: AppColors.primaryPink,
                  onChanged: (v) {
                    setState(() => _enableReminderAlarm = v);
                  },
                ),
              ),
            ],
          ),

          if (_enableReminderAlarm) ...[
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Days before:',
                  style: AppStyles.captionBubbly.copyWith(
                      fontWeight: FontWeight.bold, color: AppColors.textDark),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.pastelLavender,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: AppColors.accentBorder, width: 1.5),
                  ),
                  child: Text(
                    _reminderDays == 0
                        ? 'Same day'
                        : '$_reminderDays day${_reminderDays > 1 ? 's' : ''}',
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
                min: 0,
                max: 14,
                divisions: 14,
                onChanged: (v) => setState(() => _reminderDays = v.round()),
              ),
            ),
            const SizedBox(height: 8),
            _timeChip(_advanceAlarmTime, isDDay: false),
            const SizedBox(height: 8),
            Text('Reminder Ringtone 🎵',
                style: AppStyles.bodyBubblyBold.copyWith(fontSize: 13.0)),
            const SizedBox(height: 8),
            _ringtoneRow(
              selectedPath: _selectedAdvanceRingtonePath,
              onSelect: (path, name) => setState(() {
                _selectedAdvanceRingtonePath = path;
                _selectedAdvanceRingtoneName = name;
              }),
            ),
            if (_selectedAdvanceRingtonePath == null)
              Padding(
                padding: const EdgeInsets.only(top: 6.0),
                child: Text(
                  'No ringtone selected (system default)',
                  style: AppStyles.captionBubbly
                      .copyWith(fontStyle: FontStyle.italic),
                ),
              ),
          ],
        ],
      ),
    );
  }
}
