import 'package:flutter/material.dart';
import '../design_system/tokens/app_colors.dart' as ds;
import '../design_system/theme.dart';

/// Legacy AppColors compatibility wrapper mapped to the new AgTech design system.
abstract class AppColors {
  // ── Brand Primary & Accent ────────────────────────────────────────────────
  static const Color accent         = ds.AppColors.primary;
  static const Color accentEmphasis = ds.AppColors.primaryDark;
  static const Color accentFg       = ds.AppColors.primaryLight;
  static const Color accentLight    = ds.AppColors.primaryContainer;

  // ── Surfaces ─────────────────────────────────────────────────────────────
  static const Color canvas         = ds.AppColors.canvas;
  static const Color surface        = ds.AppColors.surface;
  static const Color surfaceOverlay = ds.AppColors.surfaceMuted;

  // ── Border ───────────────────────────────────────────────────────────────
  static const Color border         = ds.AppColors.border;
  static const Color borderMuted    = ds.AppColors.borderMuted;

  // ── Text ─────────────────────────────────────────────────────────────────
  static const Color textPrimary    = ds.AppColors.textPrimary;
  static const Color textSecondary  = ds.AppColors.textSecondary;
  static const Color textMuted      = ds.AppColors.textMuted;

  // ── Semantic ─────────────────────────────────────────────────────────────
  static const Color successEmphasis = ds.AppColors.healthy;
  static const Color successFg       = ds.AppColors.healthy;
  static const Color dangerEmphasis  = ds.AppColors.nclb;
  static const Color dangerFg        = ds.AppColors.nclb;
  static const Color attentionFg     = ds.AppColors.rust;
  static const Color doneFg          = ds.AppColors.primary;
  static const Color sponsorFg       = ds.AppColors.accent;

  // ── Dark palette ─────────────────────────────────────────────────────────
  static const Color canvasDark         = ds.AppColors.canvasDark;
  static const Color surfaceDark        = ds.AppColors.surfaceDark;
  static const Color surfaceOverlayDark = ds.AppColors.surfaceMutedDark;
  static const Color borderDark         = ds.AppColors.borderDark;
  static const Color borderMutedDark    = ds.AppColors.borderMutedDark;
  static const Color textPrimaryDark    = ds.AppColors.textPrimaryDark;
  static const Color textSecondaryDark  = ds.AppColors.textSecondaryDark;
  static const Color textMutedDark      = ds.AppColors.textMutedDark;

  // ── Disease colours ───────────────────────────────────────────────────────
  static const Color nclb    = ds.AppColors.nclb;
  static const Color rust    = ds.AppColors.rust;
  static const Color gls     = ds.AppColors.gls;
  static const Color healthy = ds.AppColors.healthy;

  static Color forClass(int classId) => ds.AppColors.forClass(classId);

  static List<BoxShadow> get cardShadow => ds.AppColors.cardShadow;

  static ThemeData get lightTheme => AppTheme.lightTheme;
  static ThemeData get darkTheme => AppTheme.darkTheme;
}
