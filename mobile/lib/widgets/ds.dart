import 'dart:ui';
import 'package:flutter/material.dart';
import '../constants/colors.dart';

// ── Spacing tokens ─────────────────────────────────────────────────────────────
abstract class AppSpacing {
  static const double xs  = 4.0;
  static const double sm  = 8.0;
  static const double md  = 16.0;
  static const double lg  = 24.0;
  static const double xl  = 32.0;
  static const double xxl = 48.0;

  static const EdgeInsets pagePad  = EdgeInsets.fromLTRB(16, 0, 16, 100);
  static const EdgeInsets cardPad  = EdgeInsets.all(16);
  static const EdgeInsets cardPadH = EdgeInsets.symmetric(horizontal: 16, vertical: 12);
}

// ── Radius tokens ──────────────────────────────────────────────────────────────
abstract class AppRadius {
  static const double sm   = 8.0;
  static const double md   = 12.0;
  static const double card = 16.0;
  static const double lg   = 20.0;
  static const double xl   = 24.0;
  static const double pill = 36.0;

  static BorderRadius get smBR   => BorderRadius.circular(sm);
  static BorderRadius get mdBR   => BorderRadius.circular(md);
  static BorderRadius get cardBR => BorderRadius.circular(card);
  static BorderRadius get lgBR   => BorderRadius.circular(lg);
  static BorderRadius get xlBR   => BorderRadius.circular(xl);
  static BorderRadius get pillBR => BorderRadius.circular(pill);
}

// ── Animation durations ────────────────────────────────────────────────────────
abstract class AppDuration {
  static const Duration fast   = Duration(milliseconds: 150);
  static const Duration normal = Duration(milliseconds: 250);
  static const Duration slow   = Duration(milliseconds: 400);
}

// ── Glassmorphic card ──────────────────────────────────────────────────────────
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.margin,
    this.padding,
    this.radius = AppRadius.card,
    this.blur = 10,
    this.opacity = 0.85,
  });

  final Widget child;
  final EdgeInsets? margin;
  final EdgeInsets? padding;
  final double radius;
  final double blur;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: margin,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Container(
            padding: padding ?? AppSpacing.cardPad,
            decoration: BoxDecoration(
              color: (isDark ? AppColors.surfaceDark : Colors.white).withOpacity(opacity),
              borderRadius: BorderRadius.circular(radius),
              border: Border.all(
                color: (isDark ? AppColors.borderDark : AppColors.border).withOpacity(0.65),
              ),
              boxShadow: AppColors.cardShadow,
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

// ── Section label ──────────────────────────────────────────────────────────────
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key, this.topMargin = 16});
  final String text;
  final double topMargin;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(top: topMargin, bottom: 10),
    child: Text(
      text.toUpperCase(),
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: 1.3,
        color: AppColors.textSecondary,
      ),
    ),
  );
}

// ── Bullet card ────────────────────────────────────────────────────────────────
class BulletCard extends StatelessWidget {
  const BulletCard({super.key, required this.items, required this.bulletColor});
  final List<String> items;
  final Color bulletColor;

  @override
  Widget build(BuildContext context) => GlassCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: items.asMap().entries.map((e) => Padding(
        padding: EdgeInsets.only(bottom: e.key < items.length - 1 ? 8 : 0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 6, height: 6,
              margin: const EdgeInsets.only(top: 6, right: 10),
              decoration: BoxDecoration(color: bulletColor, shape: BoxShape.circle),
            ),
            Expanded(child: Text(e.value,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.5))),
          ],
        ),
      )).toList(),
    ),
  );
}

// ── Solid icon — single colour, no gradient or glow ───────────────────────────
class DuotoneIcon extends StatelessWidget {
  const DuotoneIcon(
    this.icon, {
    super.key,
    this.size = 24,
    this.primaryColor = AppColors.accent,
    this.secondaryColor = AppColors.accentFg, // kept for API compat, unused
  });

  final IconData icon;
  final double size;
  final Color primaryColor;
  final Color secondaryColor;

  @override
  Widget build(BuildContext context) =>
      Icon(icon, color: primaryColor, size: size);
}

// ── Quick stat chip ────────────────────────────────────────────────────────────
class StatChip extends StatelessWidget {
  const StatChip({
    super.key,
    required this.value,
    required this.label,
    this.icon,
    this.color = AppColors.accent,
  });

  final String value;
  final String label;
  final IconData? icon;
  final Color color;

  @override
  Widget build(BuildContext context) => GlassCard(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 6),
        ],
        Text(value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: color,
              height: 1.1,
            )),
        const SizedBox(height: 3),
        Text(label,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            )),
      ],
    ),
  );
}

// ── Disease colour dot ─────────────────────────────────────────────────────────
class DiseaseDot extends StatelessWidget {
  const DiseaseDot(this.color, {super.key, this.size = 10});
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size, height: size,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
  );
}

// ── Empty state ────────────────────────────────────────────────────────────────
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
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 68, color: AppColors.textMuted),
        const SizedBox(height: 16),
        Text(title,
            style: const TextStyle(fontSize: 16, color: AppColors.textSecondary,
                fontWeight: FontWeight.w600)),
        if (subtitle != null) ...[
          const SizedBox(height: 6),
          Text(subtitle!,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: AppColors.textMuted)),
        ],
        if (action != null) ...[
          const SizedBox(height: 20),
          action!,
        ],
      ],
    ),
  );
}
