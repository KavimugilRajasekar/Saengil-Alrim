import 'package:flutter/material.dart';

class AppColors {
  // Pastel Green, Yellow, and Gold Theme Colors
  static const Color creamBg = Color(0xFFFCFAF2); // Soft cream yellowish background
  static const Color cardBg = Colors.white;
  static const Color primaryPink = Color(0xFFD2E8D4); // Light Mint/Green (Primary)
  static const Color secondaryApricot = Color(0xFFFFF8C9); // Soft Pastel Yellow (Secondary)
  static const Color pastelYellow = Color(0xFFFFF5BA); // Soft Pastel Yellow 2
  static const Color pastelMint = Color(0xFFE2F0CB); // Soft Pastel Lime Green
  static const Color pastelLavender = Color(0xFFFFE39F); // Soft Gold (Accent)
  static const Color textDark = Color(0xFF3D3A30); // Soft charcoal brown for text
  static const Color textLight = Color(0xFF8F8A7C); // Lighter muted text
  static const Color accentBorder = Color(0xFF3D3A30); // Distinct hand-drawn border color

  // A helper to get a random pastel green/yellow/gold color for avatars or cards
  static Color getRandomPastel(int index) {
    final colors = [
      primaryPink,
      secondaryApricot,
      pastelYellow,
      pastelMint,
      pastelLavender,
      const Color(0xFFFFD7A3), // Pastel Gold 2
    ];
    return colors[index % colors.length];
  }
}

class AppStyles {
  // Handwriting style fonts (PlaywriteUSModern)
  static const String handwritingFont = 'PlaywriteUSModern';
  // Bubbly modern fonts (Comfortaa)
  static const String bubblyFont = 'Comfortaa';

  // Text Styles
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

  // Box Decorations for the Funky Look
  static BoxDecoration funkyCardDecoration({
    required Color color,
    double borderRadius = 18.0,
    bool showBorder = true,
  }) {
    return BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(borderRadius),
      border: showBorder
          ? Border.all(
              color: AppColors.accentBorder,
              width: 2.5,
            )
          : null,
      boxShadow: [
        BoxShadow(
          color: AppColors.accentBorder.withValues(alpha: 0.15),
          offset: const Offset(4, 4),
          blurRadius: 0,
        ),
      ],
    );
  }

  // Dotted/dashed border drawing helper style (we'll implement custom painters or simple decoration)
  static BoxDecoration journalPageDecoration = BoxDecoration(
    color: AppColors.cardBg,
    borderRadius: BorderRadius.circular(24.0),
    border: Border.all(
      color: AppColors.accentBorder,
      width: 2.5,
    ),
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
  }) {
    return BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(
        color: AppColors.accentBorder,
        width: 2.5,
      ),
      boxShadow: const [
        BoxShadow(
          color: AppColors.accentBorder,
          offset: Offset(3, 3),
          blurRadius: 0,
        ),
      ],
    );
  }
}
