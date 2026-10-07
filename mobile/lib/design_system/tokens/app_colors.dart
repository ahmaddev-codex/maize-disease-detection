import 'package:flutter/material.dart';

/// Centralized AgTech color palette for MaizeGuard.
/// Focused on outdoor sunlight visibility, semantic disease clarity, and zero "AI Slop".
abstract class AppColors {
  // ── Brand Forest / Emerald ────────────────────────────────────────────────
  static const Color primary          = Color(0xFF134E2C); // Deep Forest Pine
  static const Color primaryDark      = Color(0xFF0D361E);
  static const Color primaryLight     = Color(0xFF1B6A3E);
  static const Color primaryContainer = Color(0xFFE5F4EC); // Soft mint tint
  static const Color onPrimary        = Colors.white;

  // Agricultural Brand Palette
  static const Color forestDark       = Color(0xFF0D361E);
  static const Color forestBase       = Color(0xFF134E2C);
  static const Color emeraldBase      = Color(0xFF16A34A);
  static const Color emeraldLight     = Color(0xFF22C55E);
  static const Color emeraldDark      = Color(0xFF15803D);

  // ── Maize Gold / Harvest Accent ───────────────────────────────────────────
  static const Color accent          = Color(0xFFD97706); // Golden Harvest
  static const Color accentLight     = Color(0xFFFEF3C7);
  static const Color accentDark      = Color(0xFFB45309);
  static const Color onAccent        = Colors.white;

  static const Color maizeGold       = Color(0xFFD97706);
  static const Color harvestGold     = Color(0xFFF59E0B);
  static const Color harvestLight    = Color(0xFFFEF3C7);

  // ── Neutral Charcoal Palette ──────────────────────────────────────────────
  static const Color charcoal50      = Color(0xFFF8FAFC);
  static const Color charcoal100     = Color(0xFFF1F5F9);
  static const Color charcoal200     = Color(0xFFE2E8F0);
  static const Color charcoal300     = Color(0xFFCBD5E1);
  static const Color charcoal400     = Color(0xFF94A3B8);
  static const Color charcoal500     = Color(0xFF64748B);
  static const Color charcoal600     = Color(0xFF475569);
  static const Color charcoal700     = Color(0xFF334155);
  static const Color charcoal800     = Color(0xFF1E293B);
  static const Color charcoal900     = Color(0xFF0F172A);
  static const Color charcoal950     = Color(0xFF020617);

  // ── Light Surfaces (Organic Paper) ────────────────────────────────────────
  static const Color canvas          = Color(0xFFF7FAF7);
  static const Color surface         = Color(0xFFFFFFFF);
  static const Color surfaceMuted    = Color(0xFFEFF4EE);
  static const Color border          = Color(0xFFDFE7DD);
  static const Color borderMuted     = Color(0xFFEDF2EC);

  // ── Dark Surfaces (Deep Humus / Soil) ─────────────────────────────────────
  static const Color canvasDark      = Color(0xFF0C140F);
  static const Color surfaceDark     = Color(0xFF142018);
  static const Color surfaceMutedDark= Color(0xFF1C2C22);
  static const Color borderDark      = Color(0xFF24382B);
  static const Color borderMutedDark = Color(0xFF1A2A20);

  // ── High Contrast Typography ──────────────────────────────────────────────
  static const Color textPrimary     = Color(0xFF131D16);
  static const Color textSecondary   = Color(0xFF4C6153);
  static const Color textMuted       = Color(0xFF7D9284);

  static const Color textPrimaryDark = Color(0xFFF1F6F2);
  static const Color textSecondaryDark = Color(0xFFA5B9AC);
  static const Color textMutedDark   = Color(0xFF6B8072);

  // ── Clinical Disease Semantics ────────────────────────────────────────────
  // Class 0: Northern Leaf Blight (NCLB) -> Terracotta / Brick Crimson
  static const Color nclb            = Color(0xFFDC2626);
  static const Color nclbContainer   = Color(0xFFFEE2E2);

  // Class 1: Common Rust -> Earthy Burnt Ochre
  static const Color rust            = Color(0xFFEA580C);
  static const Color rustContainer   = Color(0xFFFFEDD5);

  // Class 2: Gray Leaf Spot (GLS) -> Slate Olive
  static const Color gls             = Color(0xFF475569);
  static const Color glsContainer    = Color(0xFFF1F5F9);

  // Class 3: Healthy -> Fresh Leaf Emerald
  static const Color healthy         = Color(0xFF16A34A);
  static const Color healthyContainer= Color(0xFFDCFCE7);

  // ── Feedback & State Semantics ────────────────────────────────────────────
  static const Color success         = Color(0xFF16A34A);
  static const Color warning         = Color(0xFFD97706);
  static const Color danger          = Color(0xFFDC2626);
  static const Color info            = Color(0xFF0284C7);

  /// Returns the color mapped to a disease class ID (0..3)
  static Color forClass(int classId) {
    switch (classId) {
      case 0: return nclb;
      case 1: return rust;
      case 2: return gls;
      case 3: return healthy;
      default: return textSecondary;
    }
  }

  /// Returns the background container tint for a disease class
  static Color containerForClass(int classId, {bool isDark = false}) {
    if (isDark) {
      switch (classId) {
        case 0: return const Color(0xFF3B1212);
        case 1: return const Color(0xFF3D1A0A);
        case 2: return const Color(0xFF1E252E);
        case 3: return const Color(0xFF0E2C17);
        default: return surfaceMutedDark;
      }
    }
    switch (classId) {
      case 0: return nclbContainer;
      case 1: return rustContainer;
      case 2: return glsContainer;
      case 3: return healthyContainer;
      default: return surfaceMuted;
    }
  }

  /// Crisp, performant subtle card shadow (no blurry neon glow)
  static List<BoxShadow> get cardShadow => const [
    BoxShadow(
      color: Color(0x0A000000),
      blurRadius: 8,
      offset: Offset(0, 2),
    ),
  ];

  static List<BoxShadow> get elevatedShadow => const [
    BoxShadow(
      color: Color(0x14000000),
      blurRadius: 16,
      offset: Offset(0, 4),
    ),
  ];
}
