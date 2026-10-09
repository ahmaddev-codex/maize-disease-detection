import 'package:flutter/material.dart';

/// Centralized tactile, editorial color palette for MaizeGuard.
/// Inspired by modern editorial iOS craft: warm cream paper canvases,
/// punchy matte tactile folder tabs, crisp typography, and zero "AI glow slop".
abstract class AppColors {
  // ── Tactile Paper & Canvas (Light Mode) ───────────────────────────────────
  static const Color paperCream       = Color(0xFFFAF7F2); // Warm off-white organic paper
  static const Color paperSurface     = Color(0xFFFFFFFF); // Pure white card surface
  static const Color paperSurfaceMuted= Color(0xFFF3EFE6); // Soft warm parchment
  static const Color paperBorder      = Color(0xFFE8E3D8); // Subtle crisp paper edge
  static const Color paperBorderMuted = Color(0xFFF0EBE1);

  // ── Matte Obsidian Canvas (Dark Mode) ─────────────────────────────────────
  static const Color obsidianDark       = Color(0xFF121214); // True matte obsidian noir
  static const Color obsidianSurface     = Color(0xFF1C1C1F); // Elevated dark surface
  static const Color obsidianSurfaceMuted= Color(0xFF26262B); // Muted dark surface
  static const Color obsidianBorder      = Color(0xFF2E2E35); // Crisp dark border
  static const Color obsidianBorderMuted = Color(0xFF222227);

  // ── Core Surface Aliases ──────────────────────────────────────────────────
  static const Color canvas           = paperCream;
  static const Color surface          = paperSurface;
  static const Color surfaceMuted     = paperSurfaceMuted;
  static const Color border           = paperBorder;
  static const Color borderMuted      = paperBorderMuted;

  static const Color canvasDark       = obsidianDark;
  static const Color surfaceDark      = obsidianSurface;
  static const Color surfaceMutedDark = obsidianSurfaceMuted;
  static const Color borderDark       = obsidianBorder;
  static const Color borderMutedDark  = obsidianBorderMuted;

  // ── High Contrast Editorial Ink (Typography) ──────────────────────────────
  static const Color inkPrimary       = Color(0xFF111827); // Pitch ink black
  static const Color inkSecondary     = Color(0xFF4B5563); // Editorial charcoal
  static const Color inkMuted         = Color(0xFF9CA3AF); // Quiet silver caption

  static const Color inkPrimaryDark   = Color(0xFFF9FAFB); // Pure crisp white
  static const Color inkSecondaryDark = Color(0xFFD1D5DB); // Editorial light gray
  static const Color inkMutedDark     = Color(0xFF9CA3AF); // Muted caption gray

  static const Color textPrimary      = inkPrimary;
  static const Color textSecondary    = inkSecondary;
  static const Color textMuted        = inkMuted;

  static const Color textPrimaryDark  = inkPrimaryDark;
  static const Color textSecondaryDark= inkSecondaryDark;
  static const Color textMutedDark    = inkMutedDark;

  // ── Tactile Folder & Speech Bubble Palette (From Reference UI) ────────────
  // Mustard Corn Yellow (Screen 2/3 folders & bubbles)
  static const Color folderYellow     = Color(0xFFF59E0B);
  static const Color folderYellowLight= Color(0xFFFEF3C7);

  // Fresh Sprout Green (Healthy leaf & nature)
  static const Color folderGreen      = Color(0xFF10B981);
  static const Color folderGreenLight = Color(0xFFD1FAE5);

  // Electric Sky Blue (Astronomy / Telemetry / Diagnostics)
  static const Color folderBlue       = Color(0xFF3B82F6);
  static const Color folderBlueLight  = Color(0xFFDBEAFE);

  // Warm Coral Salmon (NCLB / Alert / Mikky Roo bubble)
  static const Color folderCoral      = Color(0xFFF43F5E);
  static const Color folderCoralLight = Color(0xFFFFE4E6);

  // Tangerine Ochre (Common Rust / Dennis bubble)
  static const Color folderOrange     = Color(0xFFF97316);
  static const Color folderOrangeLight= Color(0xFFFFEDD5);

  // Lavender Lilac (Cartoons / Molly bubble / Research)
  static const Color folderPurple     = Color(0xFFA855F7);
  static const Color folderPurpleLight= Color(0xFFF3E8FF);

  // Deep Matte Slate / Obsidian Card (Screen 1 "Today" header card)
  static const Color folderDark       = Color(0xFF18181B);

  // ── Brand Forest / Emerald (Agricultural Identity) ────────────────────────
  static const Color primary          = Color(0xFF0F4A28); // Deep British Racing / Pine Green
  static const Color primaryDark      = Color(0xFF09311A);
  static const Color primaryLight     = Color(0xFF166534);
  static const Color primaryContainer = Color(0xFFDCFCE7); // Soft mint container
  static const Color onPrimary        = Colors.white;

  static const Color forestDark       = Color(0xFF09311A);
  static const Color forestBase       = Color(0xFF0F4A28);
  static const Color emeraldBase      = Color(0xFF10B981);
  static const Color emeraldLight     = Color(0xFF34D399);
  static const Color emeraldDark      = Color(0xFF059669);

  // ── Harvest Gold Accent ───────────────────────────────────────────────────
  static const Color accent           = folderYellow;
  static const Color accentLight      = folderYellowLight;
  static const Color accentDark       = Color(0xFFB45309);
  static const Color onAccent         = Colors.white;

  static const Color maizeGold        = Color(0xFFF59E0B);
  static const Color harvestGold      = Color(0xFFF59E0B);
  static const Color harvestLight     = Color(0xFFFEF3C7);

  // ── Charcoal Ramp (Compatibility) ─────────────────────────────────────────
  static const Color charcoal50       = Color(0xFFF8FAFC);
  static const Color charcoal100      = Color(0xFFF1F5F9);
  static const Color charcoal200      = Color(0xFFE2E8F0);
  static const Color charcoal300      = Color(0xFFCBD5E1);
  static const Color charcoal400      = Color(0xFF94A3B8);
  static const Color charcoal500      = Color(0xFF64748B);
  static const Color charcoal600      = Color(0xFF475569);
  static const Color charcoal700      = Color(0xFF334155);
  static const Color charcoal800      = Color(0xFF1E293B);
  static const Color charcoal900      = Color(0xFF0F172A);
  static const Color charcoal950      = Color(0xFF020617);

  // ── Clinical Disease Semantics (Vibrant & Tactile) ────────────────────────
  // Class 0: Northern Leaf Blight (NCLB) -> Warm Coral Crimson
  static const Color nclb             = Color(0xFFF43F5E);
  static const Color nclbContainer    = Color(0xFFFFE4E6);

  // Class 1: Common Rust -> Earthy Tangerine Ochre
  static const Color rust             = Color(0xFFF97316);
  static const Color rustContainer    = Color(0xFFFFEDD5);

  // Class 2: Gray Leaf Spot (GLS) -> Slate Charcoal
  static const Color gls              = Color(0xFF64748B);
  static const Color glsContainer     = Color(0xFFF1F5F9);

  // Class 3: Healthy -> Fresh Sprout Green
  static const Color healthy          = Color(0xFF10B981);
  static const Color healthyContainer = Color(0xFFD1FAE5);

  // ── Feedback & State Semantics ────────────────────────────────────────────
  static const Color success          = Color(0xFF10B981);
  static const Color warning          = Color(0xFFF59E0B);
  static const Color danger           = Color(0xFFF43F5E);
  static const Color info             = Color(0xFF3B82F6);

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
        case 0: return const Color(0xFF38141B);
        case 1: return const Color(0xFF381B0C);
        case 2: return const Color(0xFF1E252E);
        case 3: return const Color(0xFF0E2E1A);
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

  // ── Tactile Physical Shadows (Never neon glows) ───────────────────────────
  static List<BoxShadow> get cardShadow => const [
    BoxShadow(
      color: Color(0x0A000000),
      blurRadius: 12,
      offset: Offset(0, 3),
    ),
  ];

  static List<BoxShadow> get elevatedShadow => const [
    BoxShadow(
      color: Color(0x12000000),
      blurRadius: 20,
      offset: Offset(0, 6),
    ),
  ];

  static List<BoxShadow> get dockShadow => const [
    BoxShadow(
      color: Color(0x14000000),
      blurRadius: 24,
      offset: Offset(0, 8),
    ),
  ];
}
