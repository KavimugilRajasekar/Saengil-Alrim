import 'dart:async';
import 'dart:math';

import 'package:alarm/alarm.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/birthday_service.dart';
import '../services/notification_service.dart';
import '../widgets/app_styles.dart';
import '../widgets/cute_sticker.dart';

/// Full-screen alarm UI shown when a birthday alarm fires.
/// Navigated to from main.dart via Alarm.ringing stream.
class AlarmRingScreen extends StatefulWidget {
  final AlarmSettings alarmSettings;
  final FriendBirthday? birthday; // null = fallback if not found
  /// Called when the screen is dismissed (stop or snooze) so the caller
  /// can clear the deduplication guard and allow re-showing if needed.
  final VoidCallback? onDismissed;

  const AlarmRingScreen({
    super.key,
    required this.alarmSettings,
    this.birthday,
    this.onDismissed,
  });

  @override
  State<AlarmRingScreen> createState() => _AlarmRingScreenState();
}

class _AlarmRingScreenState extends State<AlarmRingScreen>
    with TickerProviderStateMixin {
  // ── Animation controllers ──────────────────────────────────────
  late final AnimationController _pulseCtrl;
  late final AnimationController _ringCtrl;
  late final AnimationController _fadeCtrl;
  late final Animation<double> _pulseAnim;
  late final Animation<double> _ringAnim;
  late final Animation<double> _fadeAnim;

  // ── Confetti particles ─────────────────────────────────────────
  final List<_Particle> _particles = [];
  late final AnimationController _confettiCtrl;
  Timer? _confettiTimer;

  // ── Time display ───────────────────────────────────────────────
  late Timer _clockTimer;
  DateTime _now = DateTime.now();

  // ── Snooze state ───────────────────────────────────────────────

  @override
  void initState() {
    super.initState();

    // Force portrait, keep screen on
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    // Clock ticker
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });

    // Pulse animation for the avatar ring
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 1.0, end: 1.12).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );

    // Ring-wave animation (expanding circles)
    _ringCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
    _ringAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _ringCtrl, curve: Curves.easeOut),
    );

    // Fade-in for the whole screen
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeIn);

    // Confetti
    _confettiCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    );
    _spawnConfetti();
    _confettiCtrl.repeat();
  }

  void _spawnConfetti() {
    final rng = Random();
    _particles.clear();
    for (int i = 0; i < 60; i++) {
      _particles.add(_Particle(
        x: rng.nextDouble(),
        y: -rng.nextDouble() * 0.5,
        vx: (rng.nextDouble() - 0.5) * 0.006,
        vy: 0.003 + rng.nextDouble() * 0.005,
        color: _confettiColors[rng.nextInt(_confettiColors.length)],
        size: 6 + rng.nextDouble() * 8,
        rotation: rng.nextDouble() * 2 * pi,
        rotationSpeed: (rng.nextDouble() - 0.5) * 0.15,
        shape: rng.nextBool(),
      ));
    }
    _confettiTimer?.cancel();
    _confettiTimer = Timer.periodic(const Duration(milliseconds: 16), (_) {
      if (!mounted) return;
      setState(() {
        for (final p in _particles) {
          p.x += p.vx;
          p.y += p.vy;
          p.rotation += p.rotationSpeed;
          if (p.y > 1.1) {
            p.y = -0.05;
            p.x = Random().nextDouble();
          }
        }
      });
    });
  }

  static const _confettiColors = [
    Color(0xFFFF6B9D),
    Color(0xFFFFD93D),
    Color(0xFF6BCB77),
    Color(0xFF4D96FF),
    Color(0xFFFF922B),
    Color(0xFFCC5DE8),
    Color(0xFFFF8787),
    Color(0xFF74C0FC),
  ];

  @override
  void dispose() {
    _clockTimer.cancel();
    _confettiTimer?.cancel();
    _pulseCtrl.dispose();
    _ringCtrl.dispose();
    _fadeCtrl.dispose();
    _confettiCtrl.dispose();
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  // ── Stop alarm ─────────────────────────────────────────────────
  Future<void> _stopAlarm() async {
    final firedId = widget.alarmSettings.id;
    await Alarm.stop(firedId);
    // Reschedule both alarms to their next future occurrence.
    // Passing firedAlarmId lets NotificationService know which alarm just
    // fired so it can correctly roll only that one forward (D-Day → next year,
    // advance → recalculate from next year's D-Day if needed).
    if (widget.birthday != null) {
      await NotificationService().scheduleBirthdayAlarmsAfter(
        widget.birthday!,
        firedAlarmId: firedId,
      );
    }
    widget.onDismissed?.call();
    if (mounted) Navigator.of(context).pop();
  }

  // ── Helpers ────────────────────────────────────────────────────
  String _formatClock(DateTime dt) {
    final h = dt.hour == 0
        ? 12
        : dt.hour > 12
            ? dt.hour - 12
            : dt.hour;
    final m = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour < 12 ? 'AM' : 'PM';
    return '$h:$m $period';
  }

  String _formatDate(DateTime dt) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    const days = [
      'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'
    ];
    return '${days[dt.weekday - 1]}, ${months[dt.month - 1]} ${dt.day}';
  }

  bool get _isBirthdayToday {
    final b = widget.birthday;
    if (b == null) return false;
    return b.month == _now.month && b.day == _now.day;
  }

  @override
  Widget build(BuildContext context) {
    final b = widget.birthday;
    final themeColor = b != null
        ? AppColors.getRandomPastel(b.avatarColorIndex)
        : AppColors.primaryPink;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: FadeTransition(
        opacity: _fadeAnim,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // ── Gradient background ──────────────────────────────
            _buildBackground(themeColor),

            // ── Confetti ─────────────────────────────────────────
            CustomPaint(
              painter: _ConfettiPainter(particles: _particles),
            ),

            // ── Main content ─────────────────────────────────────
            SafeArea(
              child: Column(
                children: [
                  const SizedBox(height: 24),

                  // Clock
                  Text(
                    _formatClock(_now),
                    style: const TextStyle(
                      fontFamily: AppStyles.bubblyFont,
                      fontSize: 52,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textDark,
                    ),
                  ),
                  Text(
                    _formatDate(_now),
                    style: const TextStyle(
                      fontFamily: AppStyles.bubblyFont,
                      fontSize: 14,
                      color: AppColors.textLight,
                      letterSpacing: 0.5,
                    ),
                  ),

                  const Spacer(),

                  // ── Pulsing avatar with ring waves ───────────────
                  _buildPulsingAvatar(b, themeColor),

                  const SizedBox(height: 28),

                  // ── Name & message ───────────────────────────────
                  _buildMessage(b, themeColor),

                  const Spacer(),

                  // ── Action buttons ───────────────────────────────
                  _buildActionButtons(),

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBackground(Color themeColor) {
    // Very light, almost-transparent frosted wash —
    // tinted with the birthday person's card color at low opacity.
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            themeColor.withValues(alpha: 0.4),
            themeColor.withValues(alpha: 0.86),
            Colors.white.withValues(alpha: 0.6),
          ],
          stops: const [0.0, 0.45, 1.0],
        ),
      ),
    );
  }

  Widget _buildPulsingAvatar(FriendBirthday? b, Color themeColor) {
    return AnimatedBuilder(
      animation: Listenable.merge([_pulseAnim, _ringAnim]),
      builder: (context, _) {
        return SizedBox(
          width: 220,
          height: 220,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Expanding ring wave 1
              _RingWave(
                progress: _ringAnim.value,
                maxRadius: 110,
                color: themeColor.withValues(alpha: 0.35),
              ),
              // Expanding ring wave 2 (offset by 0.5)
              _RingWave(
                progress: (_ringAnim.value + 0.5) % 1.0,
                maxRadius: 110,
                color: themeColor.withValues(alpha: 0.20),
              ),
              // Pulsing avatar
              Transform.scale(
                scale: _pulseAnim.value,
                child: Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    color: themeColor,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.accentBorder, width: 3),
                    boxShadow: [
                      BoxShadow(
                        color: themeColor.withValues(alpha: 0.45),
                        blurRadius: 24,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: b != null
                      ? CuteSticker(sticker: b.sticker, size: 72)
                      : const Text('🎂', style: TextStyle(fontSize: 64)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMessage(FriendBirthday? b, Color themeColor) {
    final isToday = _isBirthdayToday;
    final name = b?.name ?? 'Birthday';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        children: [
          // Alarm type badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: themeColor.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.accentBorder.withValues(alpha: 0.3), width: 1.5),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.alarm_rounded, color: AppColors.textDark, size: 16),
                const SizedBox(width: 6),
                Text(
                  isToday ? 'Birthday Alarm 🎂' : 'Birthday Reminder 🎁',
                  style: const TextStyle(
                    fontFamily: AppStyles.bubblyFont,
                    fontSize: 13,
                    color: AppColors.textDark,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Main name
          Text(
            name,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: AppStyles.handwritingFont,
              fontSize: 38,
              color: AppColors.textDark,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),

          // Message
          Text(
            isToday
                ? "It's $name's birthday today!\nShow them some love 💕"
                : b != null
                    ? "$name's birthday is in ${b.daysUntil} day${b.daysUntil == 1 ? '' : 's'}!\nTime to prepare 🎁"
                    : "Don't forget this birthday!",
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: AppStyles.bubblyFont,
              fontSize: 16,
              color: AppColors.textDark,
              height: 1.5,
            ),
          ),

          // Notes preview
          if (b != null && b.notes.isNotEmpty) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: themeColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: AppColors.accentBorder.withValues(alpha: 0.2), width: 1),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.sticky_note_2_outlined,
                      color: AppColors.textLight, size: 14),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      b.notes,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: AppStyles.bubblyFont,
                        fontSize: 12,
                        color: AppColors.textLight,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: GestureDetector(
        onTap: _stopAlarm,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 18),
          decoration: AppStyles.funkyButtonDecoration(
            color: AppColors.primaryPink,
            borderRadius: 24,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.alarm_off_rounded,
                  color: AppColors.textDark, size: 24),
              const SizedBox(width: 10),
              const Text(
                'Stop Alarm',
                style: TextStyle(
                  fontFamily: AppStyles.bubblyFont,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Ring wave painter ─────────────────────────────────────────────────────────
class _RingWave extends StatelessWidget {
  final double progress;
  final double maxRadius;
  final Color color;

  const _RingWave({
    required this.progress,
    required this.maxRadius,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(maxRadius * 2, maxRadius * 2),
      painter: _RingWavePainter(
        progress: progress,
        maxRadius: maxRadius,
        color: color,
      ),
    );
  }
}

class _RingWavePainter extends CustomPainter {
  final double progress;
  final double maxRadius;
  final Color color;

  const _RingWavePainter({
    required this.progress,
    required this.maxRadius,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: color.a * (1 - progress))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawCircle(
      Offset(size.width / 2, size.height / 2),
      maxRadius * progress,
      paint,
    );
  }

  @override
  bool shouldRepaint(_RingWavePainter old) =>
      old.progress != progress || old.color != color;
}

// ── Confetti particle model ───────────────────────────────────────────────────
class _Particle {
  double x, y, vx, vy, size, rotation, rotationSpeed;
  final Color color;
  final bool isCircle;

  _Particle({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.color,
    required this.size,
    required this.rotation,
    required this.rotationSpeed,
    required bool shape,
  }) : isCircle = shape;
}

// ── Confetti painter ──────────────────────────────────────────────────────────
class _ConfettiPainter extends CustomPainter {
  final List<_Particle> particles;
  const _ConfettiPainter({required this.particles});

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      final paint = Paint()..color = p.color.withValues(alpha: 0.85);
      final cx = p.x * size.width;
      final cy = p.y * size.height;

      canvas.save();
      canvas.translate(cx, cy);
      canvas.rotate(p.rotation);

      if (p.isCircle) {
        canvas.drawCircle(Offset.zero, p.size / 2, paint);
      } else {
        canvas.drawRect(
          Rect.fromCenter(
              center: Offset.zero, width: p.size, height: p.size * 0.5),
          paint,
        );
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => true;
}
