import 'package:flutter/material.dart';
import 'package:brisconnect/theme/app_palette.dart';

/// Enhanced button styles matching the BrisConnect+ design system
class EnhancedButtonStyles {
  // ─────────────────────────────────────────────────────────────────────────
  // Primary Button Style (Ochre gradient)
  // ─────────────────────────────────────────────────────────────────────────
  static ButtonStyle primaryButton() {
    return ElevatedButton.styleFrom(
      backgroundColor: AppPalette.ochre,
      foregroundColor: Colors.white,
      shadowColor: AppPalette.ochre.withValues(alpha: 0.4),
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(28),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Secondary Button Style (Gold outline)
  // ─────────────────────────────────────────────────────────────────────────
  static ButtonStyle secondaryButton() {
    return OutlinedButton.styleFrom(
      foregroundColor: AppPalette.ochre,
      side: const BorderSide(color: AppPalette.gold, width: 2),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(28),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Tertiary Button Style (Text button with gold accent)
  // ─────────────────────────────────────────────────────────────────────────
  static ButtonStyle tertiaryButton() {
    return TextButton.styleFrom(
      foregroundColor: AppPalette.ochre,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Icon Button Style (Enhanced icon buttons)
  // ─────────────────────────────────────────────────────────────────────────
  static ButtonStyle iconButton() {
    return IconButton.styleFrom(
      foregroundColor: AppPalette.ochre,
      backgroundColor: AppPalette.surfaceAlt.withValues(alpha: 0.7),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(12),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Full-width Primary Button (for forms)
  // ─────────────────────────────────────────────────────────────────────────
  static ButtonStyle fullWidthPrimaryButton() {
    return ElevatedButton.styleFrom(
      backgroundColor: AppPalette.ochre,
      foregroundColor: Colors.white,
      shadowColor: AppPalette.ochre.withValues(alpha: 0.4),
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(30),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
      minimumSize: const Size(double.infinity, 52),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Destructive Button (for delete/remove actions)
  // ─────────────────────────────────────────────────────────────────────────
  static ButtonStyle destructiveButton() {
    return ElevatedButton.styleFrom(
      backgroundColor: Colors.red.withValues(alpha: 0.8),
      foregroundColor: Colors.white,
      shadowColor: Colors.red.withValues(alpha: 0.3),
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(28),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Enhanced Input Decoration for TextFields
  // ─────────────────────────────────────────────────────────────────────────
  static InputDecoration enhancedInputDecoration({
    required String hintText,
    required IconData prefixIcon,
    Widget? suffixIcon,
    String? errorText,
    bool isFocused = false,
  }) {
    final borderColor = isFocused
        ? AppPalette.ochre
        : AppPalette.border.withValues(alpha: 0.5);
    final focusedBorderColor = AppPalette.ochre;

    return InputDecoration(
      hintText: hintText,
      hintStyle: TextStyle(color: AppPalette.mutedText.withValues(alpha: 0.6)),
      filled: true,
      fillColor: AppPalette.surfaceAlt.withValues(alpha: 0.6),
      prefixIcon: Icon(prefixIcon, color: AppPalette.mutedText, size: 20),
      suffixIcon: suffixIcon,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(
          color: borderColor,
          width: 1.5,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(
          color: focusedBorderColor,
          width: 2,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Colors.redAccent, width: 2),
      ),
      errorText: errorText,
      errorStyle: const TextStyle(
        color: Colors.redAccent,
        fontSize: 12,
      ),
    );
  }
}
