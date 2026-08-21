import 'package:flutter/material.dart';

/// Shared dark neon theme constants for the Admin Analytics Portal only.
/// Intentionally separate from the app-wide [AppPalette] so the visitor,
/// local and business-owner screens keep their existing light theme.
class AdminNeonTheme {
  AdminNeonTheme._();

  // Backgrounds
  static const Color bgDeepNavy = Color(0xFF060A16);
  static const Color bgMidnight = Color(0xFF0A1128);
  static const Color bgVeryDark = Color(0xFF05070E);
  static const Color sidebarBg = Color(0xFF090E20);
  static const Color headerBg = Color(0xFF0B1226);

  // Glass card surfaces
  static const Color glassSurface = Color(0xFF101835);
  static const Color glassSurfaceAlt = Color(0xFF0C1330);
  static const Color glassBorder = Color(0xFF24345C);

  // Neon accents - blue + orange are the primary BrisConnect identity.
  static const Color neonBlue = Color(0xFF2FA8FF);
  static const Color neonOrange = Color(0xFFFF7A29);
  static const Color neonCyan = Color(0xFF35E4E0);
  static const Color neonPurple = Color(0xFF8B7CFF); // restrained, Premium only
  static const Color neonRed = Color(0xFFFF5D5D); // restrained, Pending Reports only

  // Text
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFC3CCEA);
  static const Color textMuted = Color(0xFF8E98BE);

  /// Dark glass panel decoration used by [AdminCard] and KPI cards.
  static BoxDecoration glassCard({
    Color accent = neonBlue,
    double radius = 16,
    double borderOpacity = 0.5,
    double borderWidth = 1.4,
  }) {
    return BoxDecoration(
      color: glassSurface.withValues(alpha: 0.78),
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(
        color: accent.withValues(alpha: borderOpacity),
        width: borderWidth,
      ),
      boxShadow: [
        BoxShadow(
          color: accent.withValues(alpha: 0.16),
          blurRadius: 20,
          offset: const Offset(0, 8),
        ),
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.35),
          blurRadius: 14,
          offset: const Offset(0, 6),
        ),
      ],
    );
  }
}
