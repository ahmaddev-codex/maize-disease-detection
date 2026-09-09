import 'package:flutter/material.dart';
import '../tokens/app_colors.dart';
import '../tokens/app_radii.dart';
import '../tokens/app_spacing.dart';

class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = AppSpacing.card,
    this.margin,
    this.onTap,
    this.accentColor,
    this.elevation = 0,
    this.color,
    this.surfaceColor,
    this.borderColor,
    this.border,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;
  final Color? accentColor;
  final double elevation;
  final Color? color;
  final Color? surfaceColor;
  final Color? borderColor;
  final BoxBorder? border;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final defaultSurface = isDark ? AppColors.surfaceDark : AppColors.surface;
    final defaultBorder = isDark ? AppColors.borderDark : AppColors.border;

    final resolvedSurface = surfaceColor ?? color ?? defaultSurface;
    final resolvedBorder = border ?? Border.all(
      color: borderColor ?? defaultBorder,
      width: 1.0,
    );

    Widget content = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: resolvedSurface,
        borderRadius: AppRadii.lgBR,
        border: resolvedBorder,
        boxShadow: elevation > 0 ? AppColors.cardShadow : null,
      ),
      child: child,
    );

    if (accentColor != null) {
      content = ClipRRect(
        borderRadius: AppRadii.lgBR,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 4, color: accentColor),
              Expanded(child: content),
            ],
          ),
        ),
      );
    }

    if (onTap != null) {
      content = Material(
        color: Colors.transparent,
        borderRadius: AppRadii.lgBR,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadii.lgBR,
          child: content,
        ),
      );
    }

    if (margin != null) {
      content = Padding(padding: margin!, child: content);
    }

    return content;
  }
}
