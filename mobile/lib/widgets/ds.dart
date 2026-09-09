import 'package:flutter/material.dart';
import '../design_system/design_system.dart';

// ── Re-export new design system tokens ─────────────────────────────────────────
export '../design_system/tokens/app_spacing.dart';
export '../design_system/tokens/app_radii.dart';
export '../design_system/components/app_card.dart';
export '../design_system/components/app_button.dart';
export '../design_system/components/severity_badge.dart';
export '../design_system/components/confidence_meter.dart';
export '../design_system/components/audio_advisory_bar.dart';
export '../design_system/components/app_text_field.dart';
export '../design_system/components/state_views.dart';

/// Clean card wrapper replacing legacy blur/glassmorphism with crisp AgTech surface.
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.margin,
    this.padding,
    this.radius = 16.0,
    this.blur = 0,
    this.opacity = 1.0,
  });

  final Widget child;
  final EdgeInsetsGeometry? margin;
  final EdgeInsetsGeometry? padding;
  final double radius;
  final double blur;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? AppColors.surfaceDark : AppColors.surface;
    final borderColor = isDark ? AppColors.borderDark : AppColors.border;

    return Container(
      margin: margin,
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: borderColor, width: 1.0),
        boxShadow: AppColors.cardShadow,
      ),
      child: child,
    );
  }
}

/// Legacy SectionLabel mapping to SectionHeader
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key, this.topMargin = 16});
  final String text;
  final double topMargin;

  @override
  Widget build(BuildContext context) => SectionHeader(text, topSpacing: topMargin);
}

/// Solid, crisp icon (no glowing shadows)
class DuotoneIcon extends StatelessWidget {
  const DuotoneIcon(
    this.icon, {
    super.key,
    this.size = 24,
    this.primaryColor = AppColors.primary,
    this.secondaryColor = AppColors.primaryLight,
  });

  final IconData icon;
  final double size;
  final Color primaryColor;
  final Color secondaryColor;

  @override
  Widget build(BuildContext context) => Icon(icon, color: primaryColor, size: size);
}

/// Quick stat chip with high contrast
class StatChip extends StatelessWidget {
  const StatChip({
    super.key,
    required this.value,
    required this.label,
    this.icon,
    this.color = AppColors.primary,
  });

  final String value;
  final String label;
  final IconData? icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.border,
          width: 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, color: color, size: 18),
            const SizedBox(height: 6),
          ],
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: color,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

/// Legacy EmptyState mapping
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.action,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 56,
              color: isDark ? AppColors.textMutedDark : AppColors.textMuted,
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 6),
              Text(
                subtitle!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
                ),
              ),
            ],
            if (action != null) ...[
              const SizedBox(height: 20),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}
