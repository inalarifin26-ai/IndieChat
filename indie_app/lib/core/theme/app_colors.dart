import 'package:flutter/material.dart';

/// Light, calm, premium palette matching the Indie reference screens:
/// white surfaces on a soft lavender-grey page, indigo→blue→cyan brand
/// gradient on primary actions and the user's own message bubbles.
class AppColors {
  AppColors._();

  // Brand (from the logo mark)
  static const Color indigo = Color(0xFF4B5CF0);
  static const Color violet = Color(0xFF6C4CF0);
  static const Color cyan = Color(0xFF1CC8F0);
  /// Selected / interactive accent (chips, links, active tab).
  static const Color accent = Color(0xFF2F7BF5);

  /// Primary buttons / FAB: left → right, as on the reference screens.
  static const LinearGradient brandGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [Color(0xFF5B47F0), Color(0xFF2F86F5), Color(0xFF1CC8F0)],
    stops: [0.0, 0.58, 1.0],
  );

  /// The user's own message bubbles.
  static const LinearGradient msgGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF5B47F0), Color(0xFF3A7CF5)],
  );

  // Surfaces
  static const Color ink = Color(0xFFF5F7FC); // page background
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceRaised = Color(0xFFEFF2FA); // soft fill (search, segmented, inputs)
  static const Color surfaceCard = Color(0xFFFFFFFF);
  static const Color stroke = Color(0xFFE4E8F2);

  // Text
  static const Color textPrimary = Color(0xFF121832);
  static const Color textSecondary = Color(0xFF586080);
  static const Color textFaint = Color(0xFF9AA2BC);

  // Semantic
  static const Color success = Color(0xFF16A34A);
  static const Color warning = Color(0xFFF59E0B);
  static const Color danger = Color(0xFFE5484D);
  static const Color approval = Color(0xFF7C5CFF);

  // Identity accents (avatars): people vs. agents stay distinguishable
  static const Color contactAccent = Color(0xFF4B5CF0);
  static const Color agentAccent = Color(0xFF8B5CF6);

  /// Pastel avatar backgrounds for people (initials), deterministic per name.
  static const List<List<Color>> pastels = [
    [Color(0xFFE6E9FF), Color(0xFF4B5CF0)],
    [Color(0xFFE0F5EA), Color(0xFF16A34A)],
    [Color(0xFFFFEBD6), Color(0xFFD9730D)],
    [Color(0xFFFBE4F0), Color(0xFFC2327D)],
    [Color(0xFFDDF3FA), Color(0xFF0E8AA8)],
    [Color(0xFFEFE7FF), Color(0xFF7C5CFF)],
  ];
}
