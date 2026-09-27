import 'package:flutter/material.dart';

/// Brand palette extracted from the Indie mark:
/// deep indigo → violet → cyan, on an ink-dark, calm, premium surface.
class AppColors {
  AppColors._();

  // Brand gradient stops (from the logo mark).
  static const Color indigo = Color(0xFF3A5CFF);
  static const Color violet = Color(0xFF6C3CE0);
  static const Color cyan = Color(0xFF2FE4DB);

  static const LinearGradient brandGradient = LinearGradient(
    begin: Alignment.bottomLeft,
    end: Alignment.topRight,
    colors: [violet, indigo, cyan],
  );

  // Ink / surfaces — calm dark base, not cyberpunk-black.
  static const Color ink = Color(0xFF0B0D14);
  static const Color surface = Color(0xFF12141C);
  static const Color surfaceRaised = Color(0xFF191C27);
  static const Color surfaceCard = Color(0xFF1E2230);
  static const Color stroke = Color(0xFF2A2E3D);

  // Text
  static const Color textPrimary = Color(0xFFF3F4F8);
  static const Color textSecondary = Color(0xFF9DA3B4);
  static const Color textFaint = Color(0xFF6A7086);

  // Semantic
  static const Color success = Color(0xFF34D399);
  static const Color warning = Color(0xFFF5B95B);
  static const Color danger = Color(0xFFEF6F6C);
  static const Color approval = Color(0xFFB48CFF);

  // Contact vs Agent identity accents (never share one color)
  static const Color contactAccent = Color(0xFF5AA9FF);
  static const Color agentAccent = Color(0xFF2FE4DB);
}
