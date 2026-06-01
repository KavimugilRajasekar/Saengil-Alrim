import 'dart:math';
import 'package:flutter/material.dart';
import '../widgets/app_styles.dart';

class ConfettiOverlay extends StatefulWidget {
  final Widget child;
  final bool trigger;

  const ConfettiOverlay({
    super.key,
    required this.child,
    required this.trigger,
  });

  @override
  State<ConfettiOverlay> createState() => _ConfettiOverlayState();
}

class _ConfettiOverlayState extends State<ConfettiOverlay> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<_Particle> _particles = [];
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );

    _controller.addListener(() {
      setState(() {
        for (var p in _particles) {
          p.update();
        }
      });
    });

    if (widget.trigger) {
      _burst();
    }
  }

  @override
  void didUpdateWidget(ConfettiOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.trigger && !oldWidget.trigger) {
      _burst();
    }
  }

  void _burst() {
    _particles.clear();
    // Soft themed confetti colors
    final colors = [
      AppColors.primaryPink,
      AppColors.secondaryApricot,
      AppColors.pastelYellow,
      AppColors.pastelMint,
      AppColors.pastelLavender,
      const Color(0xFFC3F0C2),
      const Color(0xFFFFE59E),
    ];

    // Create 45 particles bursting from top center
    for (int i = 0; i < 45; i++) {
      _particles.add(
        _Particle(
          x: 0.5, // Start centered horizontally (fractional)
          y: 0.0, // Start at the top
          vx: (_random.nextDouble() - 0.5) * 0.05, // Speed X
          vy: (_random.nextDouble() * 0.04) + 0.02, // Speed Y
          color: colors[_random.nextInt(colors.length)],
          size: (_random.nextDouble() * 8) + 6,
          rotation: _random.nextDouble() * pi * 2,
          rotationSpeed: (_random.nextDouble() - 0.5) * 0.2,
        ),
      );
    }

    _controller.forward(from: 0.0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_controller.isAnimating)
          IgnorePointer(
            child: CustomPaint(
              size: Size.infinite,
              painter: _ConfettiPainter(_particles),
            ),
          ),
      ],
    );
  }
}

class _Particle {
  double x; // Fractional width (0.0 to 1.0)
  double y; // Fractional height (0.0 to 1.0)
  double vx;
  double vy;
  Color color;
  double size;
  double rotation;
  double rotationSpeed;

  _Particle({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.color,
    required this.size,
    required this.rotation,
    required this.rotationSpeed,
  });

  void update() {
    x += vx;
    y += vy;
    // Add simple gravity/drag
    vy += 0.001;
    vx *= 0.98;
    rotation += rotationSpeed;
  }
}

class _ConfettiPainter extends CustomPainter {
  final List<_Particle> particles;

  _ConfettiPainter(this.particles);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    for (var p in particles) {
      if (p.x < 0 || p.x > 1 || p.y < 0 || p.y > 1) continue;

      paint.color = p.color;
      final px = p.x * size.width;
      final py = p.y * size.height;

      canvas.save();
      canvas.translate(px, py);
      canvas.rotate(p.rotation);

      // Draw cute rounded rect confetti particles
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset.zero, width: p.size * 1.5, height: p.size),
          Radius.circular(p.size * 0.3),
        ),
        paint,
      );

      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
