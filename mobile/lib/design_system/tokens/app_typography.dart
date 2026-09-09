import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

abstract class AppTypography {
  static const String fontFamily = 'DM Sans';

  static TextTheme textTheme({required bool isDark}) {
    final primary = isDark ? AppColors.textPrimaryDark : AppColors.textPrimary;
    final secondary = isDark ? AppColors.textSecondaryDark : AppColors.textSecondary;
    final muted = isDark ? AppColors.textMutedDark : AppColors.textMuted;

    return GoogleFonts.dmSansTextTheme().copyWith(
      displayLarge: GoogleFonts.dmSans(
        fontSize: 36,
        fontWeight: FontWeight.w800,
        color: primary,
        letterSpacing: -1.0,
      ),
      displayMedium: GoogleFonts.dmSans(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        color: primary,
        letterSpacing: -0.5,
      ),
      displaySmall: GoogleFonts.dmSans(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        color: primary,
      ),
      headlineLarge: GoogleFonts.dmSans(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        color: primary,
      ),
      headlineMedium: GoogleFonts.dmSans(
        fontSize: 19,
        fontWeight: FontWeight.w600,
        color: primary,
      ),
      headlineSmall: GoogleFonts.dmSans(
        fontSize: 17,
        fontWeight: FontWeight.w600,
        color: primary,
      ),
      titleLarge: GoogleFonts.dmSans(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: primary,
      ),
      titleMedium: GoogleFonts.dmSans(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: primary,
      ),
      titleSmall: GoogleFonts.dmSans(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: secondary,
      ),
      bodyLarge: GoogleFonts.dmSans(
        fontSize: 15,
        fontWeight: FontWeight.w400,
        color: primary,
        height: 1.5,
      ),
      bodyMedium: GoogleFonts.dmSans(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: secondary,
        height: 1.45,
      ),
      bodySmall: GoogleFonts.dmSans(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: muted,
        height: 1.4,
      ),
      labelLarge: GoogleFonts.dmSans(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: primary,
      ),
      labelMedium: GoogleFonts.dmSans(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: secondary,
      ),
      labelSmall: GoogleFonts.dmSans(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: secondary,
        letterSpacing: 0.5,
      ),
    );
  }

  /// High-contrast tabular figure style for precision metrics (confidences, counts)
  static TextStyle tabularFigures({
    required double fontSize,
    FontWeight fontWeight = FontWeight.w700,
    Color? color,
  }) {
    return GoogleFonts.dmSans(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
  }

  // ── Static TextStyles for Direct UI Access ────────────────────────────────
  static TextStyle get h1 => GoogleFonts.dmSans(
        fontSize: 28,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.5,
      );

  static TextStyle get h2 => GoogleFonts.dmSans(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
      );

  static TextStyle get h3 => GoogleFonts.dmSans(
        fontSize: 16,
        fontWeight: FontWeight.w700,
      );

  static TextStyle get bodyLarge => GoogleFonts.dmSans(
        fontSize: 15,
        fontWeight: FontWeight.w400,
        height: 1.5,
      );

  static TextStyle get bodyMedium => GoogleFonts.dmSans(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        height: 1.45,
      );

  static TextStyle get bodySmall => GoogleFonts.dmSans(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        height: 1.4,
      );

  static TextStyle get caption => GoogleFonts.dmSans(
        fontSize: 11,
        fontWeight: FontWeight.w500,
      );

  static TextStyle get overline => GoogleFonts.dmSans(
        fontSize: 10,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.2,
      );
}
