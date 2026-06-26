import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  // ── Brand purple (matches screenshot accent) ─────────────────────────────
  static const Color accent         = Color(0xFF6C47FF);
  static const Color accentEmphasis = Color(0xFF6C47FF);
  static const Color accentFg       = Color(0xFF8B6FFF);   // lighter tint
  static const Color accentLight    = Color(0xFFEDE9FF);   // tinted bg

  // ── Surfaces ─────────────────────────────────────────────────────────────
  static const Color canvas         = Color(0xFFF6F6FA);
  static const Color surface        = Color(0xFFFFFFFF);
  static const Color surfaceOverlay = Color(0xFFF0F0F8);

  // ── Border ───────────────────────────────────────────────────────────────
  static const Color border         = Color(0xFFEDEDF5);
  static const Color borderMuted    = Color(0xFFF5F5FA);

  // ── Text ─────────────────────────────────────────────────────────────────
  static const Color textPrimary    = Color(0xFF1A1A2E);
  static const Color textSecondary  = Color(0xFF8A8A9A);
  static const Color textMuted      = Color(0xFFB8B8CC);

  // ── Semantic ─────────────────────────────────────────────────────────────
  static const Color successEmphasis = Color(0xFF00A857);
  static const Color successFg       = Color(0xFF00A857);
  static const Color dangerEmphasis  = Color(0xFFFF3333);
  static const Color dangerFg        = Color(0xFFFF3333);
  static const Color attentionFg     = Color(0xFFE3A000);
  static const Color doneFg          = Color(0xFF6C47FF);
  static const Color sponsorFg       = Color(0xFFFF6B9D);

  // ── Dark palette (mirrors light, shifted dark) ────────────────────────────
  static const Color canvasDark         = Color(0xFF0F0F1A);
  static const Color surfaceDark        = Color(0xFF1A1A2E);
  static const Color surfaceOverlayDark = Color(0xFF252540);
  static const Color borderDark         = Color(0xFF2E2E4A);
  static const Color borderMutedDark    = Color(0xFF252540);
  static const Color textPrimaryDark    = Color(0xFFEEEEFF);
  static const Color textSecondaryDark  = Color(0xFF8A8A9A);
  static const Color textMutedDark      = Color(0xFF55556A);

  // ── Disease colours ───────────────────────────────────────────────────────
  static const Color nclb    = Color(0xFFFF3333);
  static const Color rust    = Color(0xFFE3A000);
  static const Color gls     = Color(0xFF6C47FF);
  static const Color healthy = Color(0xFF00A857);

  static Color forClass(int classId) {
    switch (classId) {
      case 0: return nclb;
      case 1: return rust;
      case 2: return gls;
      case 3: return healthy;
      default: return textSecondary;
    }
  }

  // ── Card shadow (purple-tinted, matches screenshot) ───────────────────────
  static List<BoxShadow> get cardShadow => [
    BoxShadow(
      color: const Color(0xFF6C47FF).withOpacity(0.08),
      blurRadius: 24,
      offset: const Offset(0, 8),
    ),
    BoxShadow(
      color: Colors.black.withOpacity(0.04),
      blurRadius: 6,
      offset: const Offset(0, 2),
    ),
  ];

  // ── Text theme (DM Sans) ──────────────────────────────────────────────────
  static TextTheme _textTheme(Color primary, Color secondary, Color muted) =>
      GoogleFonts.dmSansTextTheme().copyWith(
        displayLarge:   GoogleFonts.dmSans(fontSize: 52, fontWeight: FontWeight.w800, color: primary, letterSpacing: -2),
        displayMedium:  GoogleFonts.dmSans(fontSize: 40, fontWeight: FontWeight.w700, color: primary, letterSpacing: -1.5),
        displaySmall:   GoogleFonts.dmSans(fontSize: 32, fontWeight: FontWeight.w700, color: primary, letterSpacing: -1),
        headlineLarge:  GoogleFonts.dmSans(fontSize: 26, fontWeight: FontWeight.w700, color: primary),
        headlineMedium: GoogleFonts.dmSans(fontSize: 22, fontWeight: FontWeight.w600, color: primary),
        headlineSmall:  GoogleFonts.dmSans(fontSize: 18, fontWeight: FontWeight.w600, color: primary),
        titleLarge:     GoogleFonts.dmSans(fontSize: 17, fontWeight: FontWeight.w600, color: primary),
        titleMedium:    GoogleFonts.dmSans(fontSize: 15, fontWeight: FontWeight.w600, color: primary),
        titleSmall:     GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w600, color: secondary),
        bodyLarge:      GoogleFonts.dmSans(fontSize: 16, fontWeight: FontWeight.w400, color: primary),
        bodyMedium:     GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w400, color: secondary),
        bodySmall:      GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w400, color: muted),
        labelLarge:     GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w600, color: primary),
        labelMedium:    GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w500, color: secondary),
        labelSmall:     GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.w500, color: secondary, letterSpacing: 0.8),
      );

  // ── Light theme ───────────────────────────────────────────────────────────
  static ThemeData get lightTheme => ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    scaffoldBackgroundColor: canvas,
    colorScheme: const ColorScheme.light(
      primary:    accent,
      secondary:  successEmphasis,
      surface:    surface,
      error:      dangerEmphasis,
      onPrimary:  Colors.white,
      onSurface:  textPrimary,
      outline:    border,
    ),
    textTheme: _textTheme(textPrimary, textSecondary, textMuted),
    appBarTheme: AppBarTheme(
      backgroundColor: surface,
      foregroundColor: textPrimary,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shadowColor: Colors.transparent,
      centerTitle: false,
      titleTextStyle: GoogleFonts.dmSans(
        fontSize: 18, fontWeight: FontWeight.w700, color: textPrimary,
      ),
      iconTheme: const IconThemeData(color: textPrimary, size: 22),
    ),
    cardTheme: CardThemeData(
      color: surface,
      elevation: 0,
      shadowColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: border),
      ),
    ),
    dividerColor: border,
    dividerTheme: const DividerThemeData(color: border, space: 1, thickness: 1),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: accent,
        foregroundColor: Colors.white,
        elevation: 0,
        shadowColor: Colors.transparent,
        shape: const StadiumBorder(),
        textStyle: GoogleFonts.dmSans(fontSize: 15, fontWeight: FontWeight.w600),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 15),
        minimumSize: const Size(0, 52),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: accent,
        side: const BorderSide(color: accent, width: 1.5),
        shape: const StadiumBorder(),
        textStyle: GoogleFonts.dmSans(fontSize: 15, fontWeight: FontWeight.w600),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 15),
        minimumSize: const Size(0, 52),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: accent,
        textStyle: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w600),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surfaceOverlay,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: accent, width: 2),
      ),
      hintStyle: GoogleFonts.dmSans(color: textMuted, fontSize: 14),
      labelStyle: GoogleFonts.dmSans(color: textSecondary, fontSize: 14),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: surface,
      surfaceTintColor: Colors.transparent,
      shadowColor: Colors.transparent,
      elevation: 0,
      height: 64,
      indicatorColor: accent,
      indicatorShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const IconThemeData(color: Colors.white, size: 22);
        }
        return const IconThemeData(color: textSecondary, size: 22);
      }),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return GoogleFonts.dmSans(color: accent, fontWeight: FontWeight.w600, fontSize: 11);
        }
        return GoogleFonts.dmSans(color: textSecondary, fontWeight: FontWeight.w400, fontSize: 11);
      }),
    ),
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: surface,
      selectedItemColor: accent,
      unselectedItemColor: textSecondary,
      selectedLabelStyle: GoogleFonts.dmSans(fontWeight: FontWeight.w600, fontSize: 11),
      unselectedLabelStyle: GoogleFonts.dmSans(fontWeight: FontWeight.w400, fontSize: 11),
      type: BottomNavigationBarType.fixed,
      elevation: 0,
    ),
    chipTheme: ChipThemeData(
      backgroundColor: surfaceOverlay,
      selectedColor: accentLight,
      labelStyle: GoogleFonts.dmSans(fontSize: 13),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      side: BorderSide.none,
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: accent,
      linearTrackColor: accentLight,
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: accent,
      foregroundColor: Colors.white,
      elevation: 0,
      shape: CircleBorder(),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: textPrimary,
      contentTextStyle: GoogleFonts.dmSans(color: Colors.white, fontSize: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      behavior: SnackBarBehavior.floating,
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? Colors.white : textSecondary,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? accent : border,
      ),
    ),
  );

  // ── Dark theme ────────────────────────────────────────────────────────────
  static ThemeData get darkTheme => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: canvasDark,
    colorScheme: ColorScheme.dark(
      primary:    accent,
      secondary:  successEmphasis,
      surface:    surfaceDark,
      error:      dangerEmphasis,
      onPrimary:  Colors.white,
      onSurface:  textPrimaryDark,
      outline:    borderDark,
    ),
    textTheme: _textTheme(textPrimaryDark, textSecondaryDark, textMutedDark),
    appBarTheme: AppBarTheme(
      backgroundColor: surfaceDark,
      foregroundColor: textPrimaryDark,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shadowColor: Colors.transparent,
      centerTitle: false,
      titleTextStyle: GoogleFonts.dmSans(
        fontSize: 18, fontWeight: FontWeight.w700, color: textPrimaryDark,
      ),
      iconTheme: const IconThemeData(color: textPrimaryDark, size: 22),
    ),
    cardTheme: CardThemeData(
      color: surfaceDark,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: borderDark),
      ),
    ),
    dividerColor: borderDark,
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: accent,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: const StadiumBorder(),
        textStyle: GoogleFonts.dmSans(fontSize: 15, fontWeight: FontWeight.w600),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 15),
        minimumSize: const Size(0, 52),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surfaceOverlayDark,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: borderDark),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: borderDark),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: accent, width: 2),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: surfaceDark,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      height: 64,
      indicatorColor: accent,
      indicatorShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const IconThemeData(color: Colors.white, size: 22);
        }
        return const IconThemeData(color: textSecondaryDark, size: 22);
      }),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: surfaceDark,
      selectedItemColor: accent,
      unselectedItemColor: textSecondaryDark,
      type: BottomNavigationBarType.fixed,
      elevation: 0,
    ),
  );
}
