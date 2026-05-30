import 'dart:io';
import 'package:flutter/material.dart';

class CuteSticker extends StatelessWidget {
  final String sticker;
  final double size;
  final double? width;
  final double? height;

  const CuteSticker({
    super.key,
    required this.sticker,
    this.size = 26.0,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    final double defaultWidth = width ?? (size * 1.5);
    final double defaultHeight = height ?? (size * 1.5);

    if (sticker.startsWith('assets/sticker/')) {
      return Image.asset(
        sticker,
        width: defaultWidth,
        height: defaultHeight,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) => _buildFallbackEmoji(),
      );
    } else if (sticker.startsWith('/') || sticker.contains(':/') || sticker.contains('\\') || sticker.startsWith('file:')) {
      // It's a local file path (custom image picked from photo gallery)
      final cleanPath = sticker.startsWith('file://') ? sticker.substring(7) : sticker;
      final file = File(cleanPath);
      
      return ClipOval(
        child: Image.file(
          file,
          width: defaultWidth,
          height: defaultHeight,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => _buildFallbackEmoji(),
        ),
      );
    } else {
      // Fallback to emoji
      return _buildFallbackEmoji();
    }
  }

  Widget _buildFallbackEmoji() {
    // If it's a multi-character emoji or path error, handle it gracefully
    final displayEmoji = sticker.length > 5 ? '🎂' : sticker;
    return Text(
      displayEmoji,
      style: TextStyle(fontSize: size),
      textAlign: TextAlign.center,
    );
  }
}
