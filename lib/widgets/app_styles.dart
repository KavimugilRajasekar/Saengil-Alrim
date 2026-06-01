// app_styles.dart
// Combines: utils/styles.dart + utils/cute_route_transition.dart
// All design tokens, colors, text styles, decorations, and route transition.

import 'package:flutter/material.dart';

// ─────────────────────────────────────────────
// COLORS
// ─────────────────────────────────────────────

class AppColors {
  static const Color creamBg = Color(0xFFFCFAF2);
  static const Color cardBg = Colors.white;
  static const Color primaryPink = Color(0xFFD2E8D4);       // Light Mint/Green
  static const Color secondaryApricot = Color(0xFFFFF8C9);  // Soft Pastel Yellow
  static const Color pastelYellow = Color(0xFFFFF5BA);
  static const Color pastelMint = Color(0xFFE2F0CB);
  static const Color pastelLavender = Color(0xFFFFE39F);    // Soft Gold
  static const Color textDark = Color(0xFF3D3A30);
  static const Color textLight = Color(0xFF8F8A7C);
  static const Color accentBorder = Color(0xFF3D3A30);

  static Color getRandomPastel(int index) {
    const colors = [
      primaryPink,
      secondaryApricot,
      pastelYellow,
      pastelMint,
      pastelLavender,
      Color(0xFFFFD7A3),
    ];
    return colors[index % colors.length];
  }
}

// ─────────────────────────────────────────────
// TEXT STYLES & DECORATIONS
// ─────────────────────────────────────────────

class AppStyles {
  static const String handwritingFont = 'PlaywriteUSModern';
  static const String bubblyFont = 'Comfortaa';

  static const TextStyle titleHandwritten = TextStyle(
    fontFamily: handwritingFont,
    fontSize: 26.0,
    fontWeight: FontWeight.bold,
    color: AppColors.textDark,
  );

  static const TextStyle subtitleHandwritten = TextStyle(
    fontFamily: handwritingFont,
    fontSize: 18.0,
    color: AppColors.textDark,
  );

  static const TextStyle headerBubbly = TextStyle(
    fontFamily: bubblyFont,
    fontSize: 22.0,
    fontWeight: FontWeight.bold,
    color: AppColors.textDark,
  );

  static const TextStyle bodyBubbly = TextStyle(
    fontFamily: bubblyFont,
    fontSize: 14.0,
    color: AppColors.textDark,
    fontWeight: FontWeight.w500,
  );

  static const TextStyle bodyBubblyBold = TextStyle(
    fontFamily: bubblyFont,
    fontSize: 14.0,
    color: AppColors.textDark,
    fontWeight: FontWeight.bold,
  );

  static const TextStyle captionBubbly = TextStyle(
    fontFamily: bubblyFont,
    fontSize: 12.0,
    color: AppColors.textLight,
    fontWeight: FontWeight.w500,
  );

  static const TextStyle dateText = TextStyle(
    fontFamily: bubblyFont,
    fontSize: 16.0,
    fontWeight: FontWeight.bold,
    color: AppColors.textDark,
  );

  static BoxDecoration funkyCardDecoration({
    required Color color,
    double borderRadius = 18.0,
    bool showBorder = true,
  }) =>
      BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(borderRadius),
        border: showBorder
            ? Border.all(color: AppColors.accentBorder, width: 2.5)
            : null,
        boxShadow: [
          BoxShadow(
            color: AppColors.accentBorder.withValues(alpha: 0.15),
            offset: const Offset(4, 4),
            blurRadius: 0,
          ),
        ],
      );

  static BoxDecoration journalPageDecoration = BoxDecoration(
    color: AppColors.cardBg,
    borderRadius: BorderRadius.circular(24.0),
    border: Border.all(color: AppColors.accentBorder, width: 2.5),
    boxShadow: const [
      BoxShadow(
        color: AppColors.accentBorder,
        offset: Offset(5, 5),
        blurRadius: 0,
      ),
    ],
  );

  static BoxDecoration funkyButtonDecoration({
    required Color color,
    double borderRadius = 20.0,
  }) =>
      BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: AppColors.accentBorder, width: 2.5),
        boxShadow: const [
          BoxShadow(
            color: AppColors.accentBorder,
            offset: Offset(3, 3),
            blurRadius: 0,
          ),
        ],
      );
}

// ─────────────────────────────────────────────
// ROUTE TRANSITION
// ─────────────────────────────────────────────

class CuteRouteTransition extends PageRouteBuilder {
  final Widget page;

  CuteRouteTransition({required this.page})
      : super(
          pageBuilder: (context, animation, secondaryAnimation) => page,
          transitionDuration: const Duration(milliseconds: 500),
          reverseTransitionDuration: const Duration(milliseconds: 300),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final scaleAnimation = Tween<double>(begin: 0.85, end: 1.0).animate(
              CurvedAnimation(parent: animation, curve: Curves.elasticOut),
            );
            final fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
              CurvedAnimation(parent: animation, curve: Curves.easeInOut),
            );
            return FadeTransition(
              opacity: fadeAnimation,
              child: ScaleTransition(
                scale: scaleAnimation,
                alignment: Alignment.center,
                child: child,
              ),
            );
          },
        );
}

// ─────────────────────────────────────────────
// SHARED CONSTANTS
// ─────────────────────────────────────────────

const List<String> kMonthNamesShort = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

const List<String> kMonthNamesFull = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December',
];
